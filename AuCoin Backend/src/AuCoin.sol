// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title AuCoin
 * @author Prasad Shenoy
 */
contract AuCoin is ERC20Burnable, Ownable {
    error AuCoin__AmountMustBeMoreThanZero();
    error AuCoin__BurnAmountExceedsBalance();
    error AuCoin__NotZeroAddress();

    constructor() ERC20("AuCoin", "AUC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert AuCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert AuCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert AuCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert AuCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
