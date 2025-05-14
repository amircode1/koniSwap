// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract SwapFailuresTest is Test {

    error InvalidSwap();

    SwapCoin public swapCoin;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockPriceFeed public priceFeedA;
    MockPriceFeed public priceFeedB;
    address public user;

    function setUp() public {
        user = makeAddr("user");
        
        // Setup tokens
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        
        // Setup price feeds
        priceFeedA = new MockPriceFeed();
        priceFeedB = new MockPriceFeed();
        priceFeedA.setPrice(100 * 10 ** 8); // $100
        priceFeedB.setPrice(200 * 10 ** 8); // $200
        
        swapCoin = new SwapCoin(
            address(tokenA),
            address(tokenB),
            address(priceFeedA),
            address(priceFeedB)
        );

        // Fund the swap contract
        tokenA.mint(address(swapCoin), 1000 ether);
        tokenB.mint(address(swapCoin), 1000 ether);

        // Fund user
        tokenA.mint(user, 100 ether);
        tokenB.mint(user, 100 ether);

        // Approve tokens for user
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), type(uint256).max);
        tokenB.approve(address(swapCoin), type(uint256).max);
        vm.stopPrank();
    }

    function test_RevertWhen_SwapWithFailedTransferFrom() public {
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), 10 ether);
        
        // Make transferFrom fail
        tokenA.setShouldRevert(true);
        
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_SwapWithFailedTransfer() public {
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), 10 ether);
        
        // Make transfer fail
        tokenB.setShouldRevert(true);
        
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_SwapWithNegativePrice() public {
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), 10 ether);
        
        // Set negative price
        priceFeedA.setPrice(-100 * 10 ** 8);
        
        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_SwapWithPriceFeedFailure() public {
        // Make the price feed revert
        priceFeedA.setShouldRevert(true);

        vm.startPrank(user);
        vm.expectRevert("MockPriceFeed: latestRoundData failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();

        // Reset and test the other price feed
        priceFeedA.setShouldRevert(false);
        priceFeedB.setShouldRevert(true);

        vm.startPrank(user);
        vm.expectRevert("MockPriceFeed: latestRoundData failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_SwapWithZeroPrice() public {
        priceFeedA.setPrice(0);
        priceFeedB.setPrice(100 * 10 ** 8);

        vm.startPrank(user);
        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();

        // Reset price A and test price B at zero
        priceFeedA.setPrice(100 * 10 ** 8);
        priceFeedB.setPrice(0);

        vm.startPrank(user);
        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_SwapWithNegativePrice() public {
        priceFeedA.setPrice(-100 * 10 ** 8);

        vm.startPrank(user);
        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();

        // Reset price A and test negative price B
        priceFeedA.setPrice(100 * 10 ** 8);
        priceFeedB.setPrice(-100 * 10 ** 8);

        vm.startPrank(user);
        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_SwapWithMaxPrice() public {
        // Test with high price ratio but not excessively high
        priceFeedA.setPrice(1000 * 10 ** 8);  // $1000
        priceFeedB.setPrice(1 * 10 ** 8);  // $1

        vm.startPrank(user);
        // Try to swap an amount that would require more output than available
        tokenA.mint(user, 100 ether);
        tokenA.approve(address(swapCoin), 100 ether);
        vm.expectRevert(SwapCoin.InsufficientBalance.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 100 ether);
        vm.stopPrank();

        // But swapping a tiny amount should work
        vm.startPrank(user);
        tokenA.mint(user, 1); // Make sure we have some tokens
        tokenA.approve(address(swapCoin), 1);
        swapCoin.swap(address(tokenA), address(tokenB), 1);
        vm.stopPrank();
    }

    function test_SwapWithTransferFailure() public {
        vm.startPrank(user);
        
        // Make transferFrom fail
        tokenA.setShouldRevert(true);
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);

        // Reset transferFrom and make transfer fail
        tokenA.setShouldRevert(false);
        tokenB.setShouldRevert(true);
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        
        vm.stopPrank();
    }

    function test_SwapWithExtremelySmallAmount() public {
        vm.startPrank(user);
        vm.expectRevert(InvalidSwap.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 1);
        vm.stopPrank();
    }
}
