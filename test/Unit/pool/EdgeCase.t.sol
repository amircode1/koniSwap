// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LiquidityPool} from "../../../src/pool.sol";
import {TestLiquidityPool} from "../../Mock/TestLiquidityPool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";

contract EdgeCaseTest is Test {
    TestLiquidityPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;

    function setUp() public {
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");
        pool = new TestLiquidityPool(address(token0), address(token1));

        token0.mint(address(this), 1000 ether);
        token1.mint(address(this), 1000 ether);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
    }

    function test_AddLiquidityWithSmallAmount() public {
        // Add first liquidity
        pool.addLiquidity(1000, 1000);

        // Try adding very small amount - should still work and provide small LP
        pool.addLiquidity(1, 1);
    }

    function test_AddLiquidityInexactRatio() public {
        // First mint additional tokens since we'll need them
        token0.mint(address(this), 2000 ether);
        token1.mint(address(this), 2000 ether);

        // First add initial liquidity
        pool.addLiquidity(1000 ether, 1000 ether);

        // Try adding in different ratio - should use minimum of the two ratios
        pool.addLiquidity(100 ether, 50 ether);
    }

    function test_RemoveLiquidityMaxAmount() public {
        // First add liquidity
        pool.addLiquidity(1000 ether, 1000 ether);
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        
        // Remove all liquidity
        pool.removeLiquidity(lpBalance);
        
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
    }

    function test_MinAndSqrtHelpers() public view {
        // Test min function
        assertEq(pool.min(5, 10), 5);
        assertEq(pool.min(10, 5), 5);
        assertEq(pool.min(5, 5), 5);
        assertEq(pool.min(0, 5), 0);
        assertEq(pool.min(5, 0), 0);
        assertEq(pool.min(0, 0), 0);

        // Test sqrt function
        assertEq(pool.sqrt(0), 0);
        assertEq(pool.sqrt(1), 1);
        assertEq(pool.sqrt(2), 1);
        assertEq(pool.sqrt(3), 1);
        assertEq(pool.sqrt(4), 2);
    }
}
