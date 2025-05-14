// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LPTokenBaseTest} from "../../Base/LPTokenBaseTest.t.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ApprovalTest is LPTokenBaseTest {
    function test_Approve() public {
        vm.prank(user);
        lpToken.approve(spender, 100);
        assertEq(lpToken.allowance(user, spender), 100);
    }

    function test_ApproveToZeroAddress() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        lpToken.approve(address(0), 100);
    }

    function test_TransferFromInsufficientAllowance() public {
        uint256 amount = 500e18;
        uint256 allowance = 400e18;
        
        _mintTokens(user, amount);
        _approveTokens(user, spender, allowance);
        
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowance, amount));
        lpToken.transferFrom(user, address(this), amount);
    }
}