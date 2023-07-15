// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployAUC} from "../../script/DeployAUC.s.sol";
import {AUCEngine} from "../../src/AUCEngine.sol";
import {AuCoin} from "../../src/AuCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract AUCEngineTest is StdCheats, Test {
    AUCEngine public auce;
    AuCoin public auc;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public AuUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;
    uint256 public amountCollateral = 10 ether;
    uint256 public amountToMint = 1e8;
    address public user = address(2);
    uint256 public constant STARTING_USER_BALANCE = 100 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 25;

    //     // Liquidation
    //     address public liquidator = makeAddr("liquidator");
    //     uint256 public collateralToCover = 20 ether;
    function setUp() external {
        DeployAUC deployer = new DeployAUC();
        (auce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, AuUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        //Should we put our integration tests here?
        else {
            user = vm.addr(deployerKey);
            ERC20Mock mockErc = new ERC20Mock("MOCK", "MOCK", user, 100e18);
            MockV3Aggregator aggregatorMock = new MockV3Aggregator(
                helperConfig.DECIMALS(),
                helperConfig.ETH_USD_PRICE()
            );
            vm.etch(weth, address(mockErc).code);
            vm.etch(wbtc, address(mockErc).code);
            vm.etch(ethUsdPriceFeed, address(aggregatorMock).code);
            vm.etch(btcUsdPriceFeed, address(aggregatorMock).code);
        }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    //     ///////////////////////
    //     // Constructor Tests //
    //     ///////////////////////
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(AUCEngine.AUCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new AUCEngine(tokenAddresses, feedAddresses, AuUsdPriceFeed);
    }

    //////////////////
    // Price Tests //
    //////////////////
    function testGetTokenAmountFromUsd() public {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 1.5 ether;
        uint256 amountWeth = auce.getTokenAmountFromAU(weth, 200000000);
        ///2AUC  8 decimal
        assertEq(amountWeth, expectedWeth);
    }

    function testGetUsdValueCoin() public {
        uint256 AuAmount = 15e8;
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 22500e18;
        uint256 usdValue = auce._getUsdValueCoin(AuAmount);
        console.log(usdValue);
        console.log(expectedUsd);
        assertEq(usdValue, expectedUsd);
    }
}
