// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LiquidityPool} from "../../../src/pool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";

contract EdgeCaseLiquidityTest is Test {
    LiquidityPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;

    function setUp() public {
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");
        pool = new LiquidityPool(address(token0), address(token1));
        user = makeAddr("user");

        // Large initial amounts
        token0.mint(address(this), type(uint128).max);
        token1.mint(address(this), type(uint128).max);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
    }

    function test_AddLiquidity_ExtremelyImbalancedRatio() public {
        // First add large balanced liquidity
        uint256 initialAmount = 1e27; // 1 billion tokens
        pool.addLiquidity(initialAmount, initialAmount);

        // Try to add with extremely imbalanced ratio that would result in 0 liquidity
        vm.expectRevert(LiquidityPool.InsufficientLiquidity.selector);
        pool.addLiquidity(initialAmount, 1);
    }

    function test_AddLiquidity_MaximumValues() public {
        uint256 maxAmount = type(uint128).max; // Using uint128 to avoid overflow in sqrt
        
        // This should succeed
        pool.addLiquidity(maxAmount, maxAmount);

        // Check reserves
        assertEq(pool.reserve0(), maxAmount);
        assertEq(pool.reserve1(), maxAmount);
    }

    function test_AddLiquidity_FirstProviderMinAmount() public {
        // Test minimum amounts that would result in non-zero liquidity
        uint256 amount0 = 2;
        uint256 amount1 = 2;
        
        pool.addLiquidity(amount0, amount1);
        
        // sqrt(2*2) = 2, so we should get 2 LP tokens
        assertEq(pool.lpToken().totalSupply(), 2);
    }

    function test_RemoveLiquidity_EntirePool() public {
        // Add some initial liquidity
        pool.addLiquidity(100e18, 100e18);
        
        // Remove all liquidity
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        pool.removeLiquidity(lpBalance);

        // Verify reserves are empty
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
    }

    function test_RemoveLiquidity_SmallestAmount() public {
        // Add initial liquidity
        pool.addLiquidity(100e18, 100e18);
        
        // Try to remove 1 unit of LP token
        pool.removeLiquidity(1);

        // Verify tiny amounts were removed
        assertLt(pool.reserve0(), 100e18);
        assertLt(pool.reserve1(), 100e18);
    }
}
