// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SwapCoin} from "../../../src/swapCoin.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {MockPriceFeed} from "../../Mock/MockPriceFeed.sol";

contract TransferFailuresTest is Test {
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

        // Set price feeds
        priceFeedA.setPrice(1 ether);
        priceFeedB.setPrice(1 ether);
    }

    function test_RevertWhen_SwapWithFailedTransfer() public {
        // Setup: User tries to swap tokenA for tokenB, but tokenB transfer fails
        tokenB.setShouldRevert(true);
        
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), 10 ether);
        
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_SwapWithFailedTransferFrom() public {
        // Setup: User tries to swap tokenA for tokenB, but transferFrom for tokenA fails
        tokenA.setShouldRevert(true);
        
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), 10 ether);
        
        vm.expectRevert("MockERC20: transfer failed");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_SwapWithNegativePrice() public {
        // Setup mock price feed to return negative price
        priceFeedA.setPrice(-1);
        
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), 10 ether);
        
        vm.expectRevert("Invalid oracle price");
        swapCoin.swap(address(tokenA), address(tokenB), 10 ether);
        vm.stopPrank();
    }
}
