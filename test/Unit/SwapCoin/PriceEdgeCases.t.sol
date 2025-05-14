// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract PriceEdgeCasesTest is Test {

    error InvalidSwap();

    SwapCoin public swapCoin;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockPriceFeed public priceFeedA;
    MockPriceFeed public priceFeedB;
    
    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        
        priceFeedA = new MockPriceFeed();
        priceFeedB = new MockPriceFeed();
        
        swapCoin = new SwapCoin(
            address(tokenA),
            address(tokenB),
            address(priceFeedA),
            address(priceFeedB)
        );
        
        // Mint some tokens for swapping
        tokenA.mint(address(this), 1000 ether);
        tokenB.mint(address(this), 1000 ether);
        tokenA.mint(address(swapCoin), 1000 ether);
        tokenB.mint(address(swapCoin), 1000 ether);
        
        // Approve tokens
        tokenA.approve(address(swapCoin), type(uint256).max);
        tokenB.approve(address(swapCoin), type(uint256).max);
    }

    function test_RevertWhen_ZeroPrice() public {
        // Set price feed to return 0
        priceFeedA.setPrice(1e8); // $1
        priceFeedB.setPrice(0);   // $0

        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_RevertWhen_NegativePrice() public {
        // Set price feed to return negative value
        priceFeedA.setPrice(1e8);    // $1
        priceFeedB.setPrice(-1e8);   // -$1

        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_SwapWithVeryHighPrice() public {
        // Set an extremely high price ratio
        priceFeedA.setPrice(1e8);     // $1
        priceFeedB.setPrice(1000e8);  // $1000

        uint256 initialBalanceA = tokenA.balanceOf(address(this));
        uint256 initialBalanceB = tokenB.balanceOf(address(this));
        
        // Swap a small amount to avoid insufficient balance
        swapCoin.swap(address(tokenB), address(tokenA), 1e6);
        
        uint256 finalBalanceA = tokenA.balanceOf(address(this));
        uint256 finalBalanceB = tokenB.balanceOf(address(this));
        
        assertLt(finalBalanceB, initialBalanceB, "Balance B should decrease");
        assertGt(finalBalanceA, initialBalanceA, "Balance A should increase");
    }

    function test_SwapWithVeryLowPrice() public {
        // Set an extremely low price ratio
        priceFeedA.setPrice(1000e8);  // $1000
        priceFeedB.setPrice(1e8);     // $1

        uint256 initialBalanceA = tokenA.balanceOf(address(this));
        uint256 initialBalanceB = tokenB.balanceOf(address(this));
        
        // Swap a small amount
        swapCoin.swap(address(tokenA), address(tokenB), 1e6);
        
        uint256 finalBalanceA = tokenA.balanceOf(address(this));
        uint256 finalBalanceB = tokenB.balanceOf(address(this));
        
        assertLt(finalBalanceA, initialBalanceA, "Balance A should decrease");
        assertGt(finalBalanceB, initialBalanceB, "Balance B should increase");
    }

    function test_SwapWithUnderflow() public {
    uint256 amountIn = 1000;
    int256 priceA = 1;         // $0.00000001
    int256 priceB = 1e18;      // بسیار بزرگ

    priceFeedA.setPrice(priceA);
    priceFeedB.setPrice(priceB);

    tokenA.mint(address(this), amountIn);
    tokenA.approve(address(swapCoin), amountIn);
    tokenB.mint(address(swapCoin), 1 ether);

    uint256 expectedAmountOut = (amountIn * uint256(uint256(priceA))) / uint256(uint256(priceB));
    assertEq(expectedAmountOut, 0, "Expected amount should round down to 0");

    vm.expectRevert(InvalidSwap.selector);
    swapCoin.swap(address(tokenA), address(tokenB), amountIn);
}


    function test_SwapWithIdenticalPrices() public {
        // Set identical prices
        priceFeedA.setPrice(1e8);  // $1
        priceFeedB.setPrice(1e8);  // $1

        uint256 swapAmount = 1 ether;
        uint256 initialBalanceA = tokenA.balanceOf(address(this));
        uint256 initialBalanceB = tokenB.balanceOf(address(this));
        
        swapCoin.swap(address(tokenA), address(tokenB), swapAmount);
        
        uint256 finalBalanceA = tokenA.balanceOf(address(this));
        uint256 finalBalanceB = tokenB.balanceOf(address(this));
        
        assertEq(initialBalanceA - finalBalanceA, swapAmount, "Should swap exact amount");
        assertEq(finalBalanceB - initialBalanceB, swapAmount, "Should receive exact amount");
    }
}
