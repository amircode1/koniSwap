// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract TransferAndValidationTest is Test {
    SwapCoin public swapCoin;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public invalidToken;
    MockPriceFeed public priceFeedA;
    MockPriceFeed public priceFeedB;
    address user = address(0x123);
    
    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        invalidToken = new MockERC20("Invalid", "INV");
        
        priceFeedA = new MockPriceFeed();
        priceFeedB = new MockPriceFeed();
        
        swapCoin = new SwapCoin(
            address(tokenA),
            address(tokenB),
            address(priceFeedA),
            address(priceFeedB)
        );
        
        // Set up prices
        priceFeedA.setPrice(1e8); // $1
        priceFeedB.setPrice(1e8); // $1
        
        // Setup tokens
        tokenA.mint(address(this), 1000 ether);
        tokenB.mint(address(this), 1000 ether);
        tokenA.mint(address(swapCoin), 1000 ether);
        tokenB.mint(address(swapCoin), 1000 ether);
        tokenA.mint(user, 1000 ether);
        tokenB.mint(user, 1000 ether);
        
        // Approve tokens
        tokenA.approve(address(swapCoin), type(uint256).max);
        tokenB.approve(address(swapCoin), type(uint256).max);
    }

    function test_RevertWhen_InvalidFromToken() public {
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(address(invalidToken), address(tokenB), 1 ether);
    }
    
    function test_RevertWhen_InvalidToToken() public {
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(address(tokenA), address(invalidToken), 1 ether);
    }
    
    function test_RevertWhen_SameTokenSwap() public {
        vm.expectRevert(SwapCoin.InvalidTokenPair.selector);
        swapCoin.swap(address(tokenA), address(tokenA), 1 ether);
    }
    
    function test_RevertWhen_ZeroAmount() public {
        vm.expectRevert(SwapCoin.InvalidAmount.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 0);
    }

    function test_RevertWhen_InsufficientContractBalance() public {
        // Set prices where 1 tokenA = 10 tokenB
        priceFeedA.setPrice(10e8);  // $10
        priceFeedB.setPrice(1e8);   // $1
        
        // Drain all of contract's tokenB balance
        vm.startPrank(address(swapCoin));
        uint256 balance = tokenB.balanceOf(address(swapCoin));
        tokenB.transfer(address(this), balance);
        vm.stopPrank();
        
        vm.expectRevert(SwapCoin.InsufficientBalance.selector);
        // Try to swap 1 tokenA which should require 10 tokenB (which we don't have)
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_RevertWhen_TransferFromFailure() public {
        // Make tokenA transfers fail
        tokenA.setShouldRevert(true);
        
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_RevertWhen_TransferFailure() public {
        // Make tokenB transfers fail
        tokenB.setShouldRevert(true);
        
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_SwapWithDifferentUser() public {
        vm.startPrank(user);
        
        // Approve tokens from user
        tokenA.approve(address(swapCoin), type(uint256).max);
        tokenB.approve(address(swapCoin), type(uint256).max);
        
        uint256 swapAmount = 1 ether;
        uint256 initialBalanceA = tokenA.balanceOf(user);
        uint256 initialBalanceB = tokenB.balanceOf(user);
        
        swapCoin.swap(address(tokenA), address(tokenB), swapAmount);
        
        uint256 finalBalanceA = tokenA.balanceOf(user);
        uint256 finalBalanceB = tokenB.balanceOf(user);
        
        assertEq(initialBalanceA - finalBalanceA, swapAmount, "Should swap exact amount");
        assertEq(finalBalanceB - initialBalanceB, swapAmount, "Should receive exact amount");
        
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroAddressSender() public {
        // Try to impersonate address(0)
        vm.prank(address(0));
        
        vm.expectRevert(SwapCoin.InvalidAddress.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }
}
