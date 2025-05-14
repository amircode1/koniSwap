// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LPTokenBaseTest} from "../../Base/LPTokenBaseTest.t.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract BasicTokenTest is LPTokenBaseTest {
    function test_InitialState() public view {
        assertEq(lpToken.name(), "LP Token");
        assertEq(lpToken.symbol(), "LP");
        assertEq(lpToken.totalSupply(), 0);
        assertEq(lpToken.owner(), address(this));
    }

    function test_Transfer() public {
        uint256 amount = 100e18;
        _mintTokens(user, amount);

        vm.prank(user);
        lpToken.transfer(spender, amount);
        
        assertEq(lpToken.balanceOf(user), 0);
        assertEq(lpToken.balanceOf(spender), amount);
    }

    function test_TransferToZeroAddress() public {
        uint256 amount = 100e18;
        _mintTokens(user, amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        lpToken.transfer(address(0), amount);
    }

    function test_TransferInsufficientBalance() public {
        uint256 balance = 100e18;
        uint256 amount = 150e18;
        _mintTokens(user, balance);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, balance, amount));
        lpToken.transfer(spender, amount);
    }
}