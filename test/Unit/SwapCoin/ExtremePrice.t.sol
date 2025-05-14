// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract ExtremePriceTest is Test {
    SwapCoin public swapCoin;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockPriceFeed public priceFeedA;
    MockPriceFeed public priceFeedB;
    address public user;
    
    function setUp() public {
        user = makeAddr("user");
        
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");
        priceFeedA = new MockPriceFeed();
        priceFeedB = new MockPriceFeed();
        
        swapCoin = new SwapCoin(
            address(tokenA),
            address(tokenB),
            address(priceFeedA),
            address(priceFeedB)
        );

        // Initial setup
        tokenA.mint(address(swapCoin), 1000 ether);
        tokenB.mint(address(swapCoin), 1000 ether);
        tokenA.mint(user, 100 ether);
        tokenB.mint(user, 100 ether);

        vm.startPrank(user);
        tokenA.approve(address(swapCoin), type(uint256).max);
        tokenB.approve(address(swapCoin), type(uint256).max);
        vm.stopPrank();
    }

    function test_SwapWithExtremelyHighPrice() public {
        priceFeedA.setPrice(type(int256).max);  // Maximum possible price for tokenA
        priceFeedB.setPrice(1e8);  // $1 for tokenB

        vm.startPrank(user);
        
        // Even with a tiny amount in, the output would be huge
        vm.expectRevert(SwapCoin.InsufficientBalance.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 1);

        vm.stopPrank();
    }

    function test_SwapWithPriceRatioBoundary() public {
        // Set a high but not overflowing price ratio
        priceFeedA.setPrice(1000_000e8);  // $1M
        priceFeedB.setPrice(1e8);         // $1

        vm.startPrank(user);
        
        // With this ratio, even 1 ether input would require 1M ether output
        // which is more than the contract's balance
        vm.expectRevert(SwapCoin.InsufficientBalance.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
        
        vm.stopPrank();
    }

    function test_SwapWithZeroAmount() public {
        priceFeedA.setPrice(1e8); // $1
        priceFeedB.setPrice(1e8); // $1

        vm.startPrank(user);
        vm.expectRevert(SwapCoin.InvalidAmount.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 0);
        vm.stopPrank();
    }

    function test_SwapWithInvalidSender() public {
        // Create a contract that will try to swap with address(0) as msg.sender
        vm.startPrank(address(0));
        vm.expectRevert(SwapCoin.InvalidAddress.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
        vm.stopPrank();
    }
}
