// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AuCoin} from "./AuCoin.sol";

/*
 * @title AuCoin
 * @author Prasad Shenoy
 */
contract AUCEngine is ReentrancyGuard {
    error AUCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error AUCEngine__NeedsMoreThanZero();
    error AUCEngine__TokenNotAllowed(address token);
    error AUCEngine__TransferFailed();
    error AUCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error AUCEngine__MintFailed();
    error AUCEngine__HealthFactorOk();
    error AUCEngine__HealthFactorNotImproved();

    using OracleLib for AggregatorV3Interface;

    AuCoin private immutable i_Auc;
    address private immutable i_auPricefeed;

    uint256 private constant LIQUIDATION_THRESHOLD = 75; // This means you need to be 150% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;
    /// @dev Mapping of token address to price feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    /// @dev Amount of AUC minted by user
    mapping(address user => uint256 amount) private s_AUCMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, uint256 indexed amountCollateral, address from, address to); // if from != to, then it was liquidated

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert AUCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert AUCEngine__TokenNotAllowed(token);
        }
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address AuUsdPriceFeed) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert AUCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_Auc = new AuCoin();
        i_auPricefeed = AuUsdPriceFeed;
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToMint: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintAuc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountAucToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintAuc(amountAucToMint);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToBurn: The amount of DSC you want to burn
     * @notice This function will withdraw your collateral and burn DSC in one transaction
     */

    function redeemCollateralForAuc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountAucToBurn)
        external
        moreThanZero(amountCollateral)
    {
        _burnAuc(amountAucToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnAuc(uint256 amount) external moreThanZero(amount) {
        _burnAuc(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of DSC you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert AUCEngine__HealthFactorOk();
        }
        // If covering 100 DSC, we need to $100 of collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromAU(collateral, debtToCover);
        // And give them a 10% bonus
        // And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / 100;
        // Burn DSC equal to debtToCover
        // Figure out how much collateral to recover based on how much burnt
        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnAuc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert AUCEngine__HealthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param amountDscToMint: The amount of DSC you want to mint
     * You can only mint DSC if you hav enough collateral
     */
    function mintAuc(uint256 amountAucToMint) public moreThanZero(amountAucToMint) nonReentrant {
        s_AUCMinted[msg.sender] += amountAucToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_Auc.mint(msg.sender, amountAucToMint);

        if (minted != true) {
            revert AUCEngine__MintFailed();
        }
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert AUCEngine__TransferFailed();
        }
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, amountCollateral, from, to);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert AUCEngine__TransferFailed();
        }
    }

    function _burnAuc(uint256 amountAucToBurn, address onBehalfOf, address AucFrom) private {
        s_AUCMinted[onBehalfOf] -= amountAucToBurn;

        bool success = i_Auc.transferFrom(AucFrom, address(this), amountAucToBurn);
        if (!success) {
            revert AUCEngine__TransferFailed();
        }
        i_Auc.burn(amountAucToBurn);
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalAucMinted, uint256 collateralValueInAU)
    {
        totalAucMinted = s_AUCMinted[user];
        collateralValueInAU = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalAucMinted, uint256 collateralValueInAU) = _getAccountInformation(user);
        return _calculateHealthFactor(totalAucMinted, collateralValueInAU);
    }

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _getUsdValueInAU(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 tokenprice,,,) = priceFeed.staleCheckLatestRoundData(); ////8 decimal
        AggregatorV3Interface AUpriceFeed = AggregatorV3Interface(i_auPricefeed);
        (, int256 AUprice,,,) = AUpriceFeed.staleCheckLatestRoundData();

        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((((uint256(tokenprice) * FEED_PRECISION) / uint256(AUprice)) * amount) / PRECISION);
    }

    function getUsdValue(address token, uint256 amount) external view returns (uint256) {
        return (_getUsdValue(token, amount));
    }

    function _getUsdValueCoin(uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_auPricefeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH = 1000 USD ...testing
        // The returned value from Chainlink will be 1000 * 1e8
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return (((uint256(price) * ADDITIONAL_FEED_PRECISION) * (amount * ADDITIONAL_FEED_PRECISION)) / PRECISION);
        ///returns 18 decimal
        ///amount should be with 8 decimal
    }

    function _calculateHealthFactor(uint256 totalAuCMinted, uint256 collateralValueInAU)
        internal
        pure
        returns (uint256)
    {
        if (totalAuCMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInAU * LIQUIDATION_THRESHOLD) / 100;
        return (collateralAdjustedForThreshold * 1e18) / totalAuCMinted;
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert AUCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function calculateHealthFactor(uint256 totalAucMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalAucMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalAucMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function gettokenValueInAU(
        address token,
        uint256 amount // in WEI
    ) public view returns (uint256) {
        return _getUsdValueInAU(token, amount);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInAU) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInAU += gettokenValueInAU(token, amount);
        }
        return totalCollateralValueInAU;
    }

    function getTokenAmountFromAU(address token, uint256 debtToCover) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        /// 8 decimal
        uint256 AuPrice = _getUsdValueCoin(debtToCover); //// 18decimal
        // $100e18 USD Debt
        // 1 ETH = 2000 USD
        // The returned value from Chainlink will be 2000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        return ((AuPrice * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
        ///18decimal
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getAuc() external view returns (address) {
        return address(i_Auc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
