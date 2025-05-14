// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LPToken} from "../src/LPToken.sol";
import {LPTokenBaseTest} from "./Base/LPTokenBaseTest.t.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

error OwnableUnauthorizedAccount(address account);

contract LPTokenTest is LPTokenBaseTest {
    // ============ Test Basic Functions ============
    function test_InitialState() public view{
        assertEq(lpToken.name(), "LP Token");
        assertEq(lpToken.symbol(), "LP");
        assertEq(lpToken.totalSupply(), 0);
        assertEq(lpToken.owner(), address(this));
    }

    // ============ Test Transfer Functions ============
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

    // ============ Test Approval Functions ============
    function test_Approve() public {
        uint256 amount = 100e18;

        vm.prank(user);
        lpToken.approve(spender, amount);

        assertEq(lpToken.allowance(user, spender), amount);
    }

    function test_ApproveToZeroAddress() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        lpToken.approve(address(0), 100e18);
    }

    // ============ Test TransferFrom Function ============
    function test_TransferFrom() public {
        uint256 amount = 100e18;
        _mintTokens(user, amount);
        _approveTokens(user, spender, amount);

        vm.prank(spender);
        lpToken.transferFrom(user, address(this), amount);

        assertEq(lpToken.balanceOf(user), 0);
        assertEq(lpToken.balanceOf(address(this)), amount);
        assertEq(lpToken.allowance(user, spender), 0);
    }

    function test_TransferFromInsufficientAllowance() public {
        uint256 amount = 500e18;
        uint256 allowance = 400e18;
        
        _mintTokens(user, amount);
        _approveTokens(user, spender, allowance);
        
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowance, amount));
        lpToken.transferFrom(user, spender, amount);
    }

    // ============ Test Minting Functions ============
    function test_Mint() public {
        uint256 amount = 100e18;
        lpToken.mint(user, amount);
        assertEq(lpToken.balanceOf(user), amount);
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

    // ============ Test Burning Functions ============
    function test_Burn() public {
        uint256 amount = 100e18;
        lpToken.mint(user, amount);

        lpToken.burn(user, amount);
        assertEq(lpToken.balanceOf(user), 0);
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

    // ============ Test Ownership Functions ============
    function test_OwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");
        
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), newOwner);
        
        lpToken.transferOwnership(newOwner);
        assertEq(lpToken.owner(), newOwner);
        
        // Test that old owner can't mint anymore
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        lpToken.mint(user, 100e18);
    }

    function test_RenounceOwnership() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), address(0));
        
        lpToken.renounceOwnership();
        assertEq(lpToken.owner(), address(0));
        
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        lpToken.mint(user, 100e18);
    }

    // ============ Test Fuzz Functions ============
    function testFuzz_Mint(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);
        lpToken.mint(user, amount);
        assertEq(lpToken.balanceOf(user), amount);
    }
    
    function testFuzz_Burn(uint256 amount, uint256 burnAmount) public {
        amount = bound(amount, 0, type(uint128).max); // Avoid overflow
        burnAmount = bound(burnAmount, 0, amount);
        
        lpToken.mint(user, amount);
        lpToken.burn(user, burnAmount);
        assertEq(lpToken.balanceOf(user), amount - burnAmount);
    }
    
    function testFuzz_ApproveAndTransferFrom(uint256 amount, uint256 transferAmount) public {
        amount = bound(amount, 0, type(uint128).max); // Avoid overflow
        transferAmount = bound(transferAmount, 0, amount);
        
        lpToken.mint(user, amount);
        
        vm.prank(user);
        lpToken.approve(spender, transferAmount);
        
        vm.prank(spender);
        lpToken.transferFrom(user, spender, transferAmount);
        
        assertEq(lpToken.balanceOf(spender), transferAmount);
        assertEq(lpToken.balanceOf(user), amount - transferAmount);
    }
}