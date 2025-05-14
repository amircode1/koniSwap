// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    bool private shouldRevert;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        shouldRevert = false;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        if (shouldRevert) {
            revert("MockERC20: transfer failed");
        }
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        if (shouldRevert) {
            revert("MockERC20: transfer failed");
        }
        return super.transferFrom(from, to, amount);
    }
}