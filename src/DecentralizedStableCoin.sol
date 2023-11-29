// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error DecentralizedStableCoin__notEnoughBalance();
error DecentralizedStableCoin__MustMoreThanZero();
error DecentralizedStableCoin__notZeroAddress();

/* @title Decentralized Stable Coin
 * @author Fred
 * @dev This contract is a decentralized stable coin
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    constructor() ERC20("Decentralized Stable Coin", "DSC") {}

    function mint(
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert DecentralizedStableCoin__notZeroAddress();
        }
        if (amount <= 0) {
            revert DecentralizedStableCoin__MustMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (balance < amount) {
            revert DecentralizedStableCoin__notEnoughBalance();
        }
        if (amount <= 0) {
            revert DecentralizedStableCoin__MustMoreThanZero();
        }
        super.burn(amount);
    }
}
