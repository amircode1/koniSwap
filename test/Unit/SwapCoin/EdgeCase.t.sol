// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract EdgeCaseTest is Test {
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

        tokenA.mint(address(swapCoin), 1000 ether);
        tokenB.mint(address(swapCoin), 1000 ether);
    }

    function test_SwapWithZeroPrice() public {
        tokenA.mint(address(this), 10 ether);
        tokenA.approve(address(swapCoin), 10 ether);

        priceFeedA.setPrice(0);
        priceFeedB.setPrice(100 * 10 ** 8);

        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }

    function test_SwapWithPriceDifference() public {
        // Set very different prices to test calculation accuracy
        priceFeedA.setPrice(1 * 10 ** 8);  // $1
        priceFeedB.setPrice(1000 * 10 ** 8);  // $1000

        tokenA.mint(address(this), 1000 ether);
        tokenA.approve(address(swapCoin), 1000 ether);

        // Should get much less of token B due to price difference
        swapCoin.swap(address(tokenA), address(tokenB), 1000 ether);
    }

    function test_SwapWithMaxPrice() public {
        // Set high but valid price
        int256 highPrice = 1000 * 10 ** 8;  // $1000
        priceFeedA.setPrice(highPrice);
        priceFeedB.setPrice(1 * 10 ** 8);  // $1

        tokenA.mint(address(this), 1 ether);
        tokenA.approve(address(swapCoin), 1 ether);

        // This should work since the amount out won't exceed the contract's balance
        swapCoin.swap(address(tokenA), address(tokenB), 1 ether);
    }
}
