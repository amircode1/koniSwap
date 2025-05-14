// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract InvalidTokenTest is Test {
    SwapCoin public swapCoin;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public invalidToken;
    MockPriceFeed public priceFeedA;
    MockPriceFeed public priceFeedB;
    
    function setUp() public {
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");
        invalidToken = new MockERC20("Invalid", "INV");
        priceFeedA = new MockPriceFeed();
        priceFeedB = new MockPriceFeed();
        
        swapCoin = new SwapCoin(
            address(tokenA),
            address(tokenB),
            address(priceFeedA),
            address(priceFeedB)
        );
    }

    function test_SwapInvalidFromToken() public {
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(address(invalidToken), address(tokenB), 1 ether);
    }

    function test_SwapInvalidToToken() public {
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(address(tokenA), address(invalidToken), 1 ether);
    }

    function test_SwapSameToken() public {
        vm.expectRevert(SwapCoin.InvalidTokenPair.selector);
        swapCoin.swap(address(tokenA), address(tokenA), 1 ether);
    }

    function test_SwapInvalidTokenPairs() public {
        // Try all invalid combinations
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(address(invalidToken), address(invalidToken), 1 ether);

        vm.expectRevert(SwapCoin.InvalidTokenPair.selector);
        swapCoin.swap(address(tokenB), address(tokenB), 1 ether);

        MockERC20 anotherInvalidToken = new MockERC20("Another", "ANT");
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(address(anotherInvalidToken), address(invalidToken), 1 ether);
    }
}
