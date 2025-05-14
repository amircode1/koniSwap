// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title LPToken
 * @dev توکن LP که فقط توسط قرارداد استخر نقدینگی مینت و سوزانده می‌شود
 */
contract LPToken is ERC20, Ownable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {
        // توکن LP فقط توسط قرارداد استخر نقدینگی مینت و سوزانده می‌شود
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert IERC20Errors.ERC20InvalidReceiver(address(0));
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        if (from == address(0)) revert IERC20Errors.ERC20InvalidSender(address(0));
        _burn(from, amount);
    }
}
