
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract PriceFeedValidationTest is Test {
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
        
        // Setup tokens
        tokenA.mint(address(this), 1000 ether);
        tokenB.mint(address(this), 1000 ether);
        tokenA.mint(address(swapCoin), 1000 ether);
        tokenB.mint(address(swapCoin), 1000 ether);
        
        // Approve tokens
        tokenA.approve(address(swapCoin), type(uint256).max);
        tokenB.approve(address(swapCoin), type(uint256).max);
    }

    function test_RevertWhen_InvalidPriceFeedA() public {
        // Set valid price for token B
        priceFeedB.setPrice(1e8);
        
        // Set invalid price (zero) for token A
        priceFeedA.setPrice(0);

        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_RevertWhen_InvalidPriceFeedB() public {
        // Set valid price for token A
        priceFeedA.setPrice(1e8);
        
        // Set invalid price (zero) for token B
        priceFeedB.setPrice(0);

        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_RevertWhen_NegativePriceFeedA() public {
        // Set valid price for token B
        priceFeedB.setPrice(1e8);
        
        // Set negative price for token A
        priceFeedA.setPrice(-1e8);

        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_RevertWhen_NegativePriceFeedB() public {
        // Set valid price for token A
        priceFeedA.setPrice(1e8);
        
        // Set negative price for token B
        priceFeedB.setPrice(-1e8);

        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_PriceFeedSelectionLogic() public {
        // Set different prices for token A and B
        priceFeedA.setPrice(1e8);   // $1
        priceFeedB.setPrice(2e8);   // $2

        // Test swap from A to B (should use priceFeedA and priceFeedB)
        uint256 amountA = 1 ether;
        uint256 expectedB = (amountA * 1e8) / 2e8;  // 0.5 ether
        
        uint256 balanceABefore = tokenA.balanceOf(address(this));
        uint256 balanceBBefore = tokenB.balanceOf(address(this));
        
        swapCoin.swap(address(tokenA), address(tokenB), amountA);
        
        uint256 balanceAAfter = tokenA.balanceOf(address(this));
        uint256 balanceBAfter = tokenB.balanceOf(address(this));
        
        assertEq(balanceABefore - balanceAAfter, amountA, "Should spend correct amount of A");
        assertEq(balanceBAfter - balanceBBefore, expectedB, "Should receive correct amount of B");
    }
}
