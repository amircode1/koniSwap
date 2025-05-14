// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {SwapCoin} from "../src/swapCoin.sol";
import {MockERC20} from "./Mock/MockERC20.sol";
import {MockPriceFeed} from "./Mock/MockPriceFeed.sol";
import {AggregatorV3Interface} from "./Mock/AggregatorV3Interface.sol";

contract SwapCoinTest is Test {
    SwapCoin public swapCoin;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockPriceFeed public priceFeedA;
    MockPriceFeed public priceFeedB;
    
    address public user;
    uint256 public constant INITIAL_BALANCE = 1000e18;
    int256 public constant INITIAL_PRICE_A = 100 * 10 ** 8; // $100
    int256 public constant INITIAL_PRICE_B = 200 * 10 ** 8; // $200

    function setUp() public {
        user = makeAddr("user");
        
        // Deploy mock tokens
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        
        // Deploy mock price feeds
        priceFeedA = new MockPriceFeed();
        priceFeedB = new MockPriceFeed();
        priceFeedA.setPrice(INITIAL_PRICE_A);
        priceFeedB.setPrice(INITIAL_PRICE_B);
        
        // Deploy swap contract
        swapCoin = new SwapCoin(
            address(tokenA),
            address(tokenB),
            address(priceFeedA),
            address(priceFeedB)
        );
        
        // Setup initial token balances
        tokenA.mint(address(swapCoin), INITIAL_BALANCE);
        tokenB.mint(address(swapCoin), INITIAL_BALANCE);
        tokenA.mint(user, INITIAL_BALANCE);
        tokenB.mint(user, INITIAL_BALANCE);
        
        // Approve tokens for user
        vm.startPrank(user);
        tokenA.approve(address(swapCoin), type(uint256).max);
        tokenB.approve(address(swapCoin), type(uint256).max);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(address(swapCoin.tokenA()), address(tokenA));
        assertEq(address(swapCoin.tokenB()), address(tokenB));
        assertEq(address(swapCoin.priceFeedA()), address(priceFeedA));
        assertEq(address(swapCoin.priceFeedB()), address(priceFeedB));
    }

    function test_SwapAToB() public {
        uint256 amountIn = 100e18;
        uint256 expectedAmountOut = (amountIn * uint256(INITIAL_PRICE_A)) / uint256(INITIAL_PRICE_B);
        
        uint256 userBalanceABefore = tokenA.balanceOf(user);
        uint256 userBalanceBBefore = tokenB.balanceOf(user);
        
        vm.prank(user);
        swapCoin.swap(address(tokenA), address(tokenB), amountIn);
        
        assertEq(tokenA.balanceOf(user), userBalanceABefore - amountIn);
        assertEq(tokenB.balanceOf(user), userBalanceBBefore + expectedAmountOut);
    }

    function test_SwapBToA() public {
        uint256 amountIn = 100e18;
        uint256 expectedAmountOut = (amountIn * uint256(INITIAL_PRICE_B)) / uint256(INITIAL_PRICE_A);
        
        uint256 userBalanceABefore = tokenA.balanceOf(user);
        uint256 userBalanceBBefore = tokenB.balanceOf(user);
        
        vm.prank(user);
        swapCoin.swap(address(tokenB), address(tokenA), amountIn);
        
        assertEq(tokenB.balanceOf(user), userBalanceBBefore - amountIn);
        assertEq(tokenA.balanceOf(user), userBalanceABefore + expectedAmountOut);
    }

    function test_SwapWithPriceChange() public {
        // Change price of token A
        int256 newPriceA = 150 * 10 ** 8; // $150
        priceFeedA.setPrice(newPriceA);
        
        uint256 amountIn = 100e18;
        uint256 expectedAmountOut = (amountIn * uint256(newPriceA)) / uint256(INITIAL_PRICE_B);
        
        vm.prank(user);
        swapCoin.swap(address(tokenA), address(tokenB), amountIn);
        
        assertEq(tokenB.balanceOf(user), INITIAL_BALANCE + expectedAmountOut);
    }

    function test_RevertInvalidToken() public {
        address invalidToken = makeAddr("invalid");
        
        vm.startPrank(user);
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(invalidToken, address(tokenB), 100e18);
        
        vm.expectRevert(SwapCoin.InvalidToken.selector);
        swapCoin.swap(address(tokenA), invalidToken, 100e18);
        vm.stopPrank();
    }

    function test_RevertInvalidTokenPair() public {
        vm.startPrank(user);
        vm.expectRevert(SwapCoin.InvalidTokenPair.selector);
        swapCoin.swap(address(tokenA), address(tokenA), 100e18);
        vm.stopPrank();
    }

    function test_RevertInvalidAmount() public {
        vm.startPrank(user);
        vm.expectRevert(SwapCoin.InvalidAmount.selector);
        swapCoin.swap(address(tokenA), address(tokenB), 0);
        vm.stopPrank();
    }

    function test_RevertInsufficientBalance() public {
        uint256 swapAmount = 10000e18;  // Much more than INITIAL_BALANCE to ensure the output amount exceeds contract balance

        // First mint enough tokens to the user to perform the swap
        tokenA.mint(user, swapAmount);
        tokenB.mint(user, swapAmount);

        vm.startPrank(user);
        // Approve the tokens
        tokenA.approve(address(swapCoin), swapAmount);
        tokenB.approve(address(swapCoin), swapAmount);

        vm.expectRevert(SwapCoin.InsufficientBalance.selector);
        swapCoin.swap(address(tokenA), address(tokenB), swapAmount);

        // Also test swapping B to A
        vm.expectRevert(SwapCoin.InsufficientBalance.selector);
        swapCoin.swap(address(tokenB), address(tokenA), swapAmount);
        
        vm.stopPrank();
    }

    function testFuzz_Swap(uint256 amountIn) public {
        // Bound input to reasonable values
        amountIn = bound(amountIn, 1e18, INITIAL_BALANCE);
        
        uint256 expectedAmountOut = (amountIn * uint256(INITIAL_PRICE_A)) / uint256(INITIAL_PRICE_B);
        
        vm.assume(expectedAmountOut <= INITIAL_BALANCE);
        
        vm.prank(user);
        swapCoin.swap(address(tokenA), address(tokenB), amountIn);
        
        assertEq(tokenA.balanceOf(user), INITIAL_BALANCE - amountIn);
        assertEq(tokenB.balanceOf(user), INITIAL_BALANCE + expectedAmountOut);
    }
}