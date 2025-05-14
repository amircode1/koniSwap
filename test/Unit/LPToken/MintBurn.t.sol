// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LPTokenBaseTest} from "../../Base/LPTokenBaseTest.t.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

error OwnableUnauthorizedAccount(address account);

contract MintBurnTest is LPTokenBaseTest {
    function test_Mint() public {
        uint256 amount = 100e18;
        lpToken.mint(user, amount);
        assertEq(lpToken.balanceOf(user), amount);
        assertEq(lpToken.totalSupply(), amount);
    }

    function test_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        lpToken.mint(address(0), 100e18);
    }

    function test_MintFailsNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user));
        lpToken.mint(spender, 100e18);
    }

    function test_Burn() public {
        uint256 amount = 100e18;
        lpToken.mint(user, amount);

        lpToken.burn(user, amount);
        assertEq(lpToken.balanceOf(user), 0);
        assertEq(lpToken.totalSupply(), 0);
    }

    function test_BurnFailsInsufficientBalance() public {
        uint256 balance = 100e18;
        uint256 burnAmount = 150e18;
        lpToken.mint(user, balance);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, balance, burnAmount));
        lpToken.burn(user, burnAmount);
    }

    function test_BurnFailsNonOwner() public {
        uint256 amount = 100e18;
        lpToken.mint(user, amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user));
        lpToken.burn(user, amount);
    }

    function test_BurnFromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        lpToken.burn(address(0), 100);
    }
}