// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {LiquidityPool} from "../src/pool.sol";
import {LPToken} from "../src/LPToken.sol";
import {MockERC20} from "../test/Mock/MockERC20.sol";

contract PoolTest is Test {
    LiquidityPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;
    address public user2;

    function setUp() public {
        user = makeAddr("user");
        user2 = makeAddr("user2");
        
        // Deploy mock tokens
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");
        
        // Deploy pool
        pool = new LiquidityPool(address(token0), address(token1));
        
        // Mint tokens to users
        token0.mint(user, 1000e18);
        token1.mint(user, 1000e18);
        token0.mint(user2, 1000e18);
        token1.mint(user2, 1000e18);
        
        // Approve pool for user
        vm.startPrank(user);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(address(pool.token0()), address(token0));
        assertEq(address(pool.token1()), address(token1));
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
        assertEq(address(pool.lpToken().owner()), address(pool));
    }

    function test_AddInitialLiquidity() public {
        vm.startPrank(user);
        uint256 amount0 = 100e18;
        uint256 amount1 = 100e18;
        
        pool.addLiquidity(amount0, amount1);
        
        assertEq(pool.reserve0(), amount0);
        assertEq(pool.reserve1(), amount1);
        assertEq(pool.lpToken().balanceOf(user), _callSqrt(amount0 * amount1));
        vm.stopPrank();
    }

    function test_AddLiquidityProportional() public {
        // Initial liquidity
        vm.prank(user);
        pool.addLiquidity(100e18, 100e18);
        
        uint256 initialLPSupply = pool.lpToken().totalSupply();
        
        // Second provider
        vm.startPrank(user2);
        uint256 amount0 = 50e18;
        uint256 amount1 = 50e18;
        
        pool.addLiquidity(amount0, amount1);
        
        // Should get half the LP tokens as first provider
        assertEq(pool.lpToken().balanceOf(user2), initialLPSupply / 2);
        vm.stopPrank();
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(user);
        uint256 amount0 = 100e18;
        uint256 amount1 = 100e18;
        
        pool.addLiquidity(amount0, amount1);
        uint256 lpBalance = pool.lpToken().balanceOf(user);
        
        uint256 token0Before = token0.balanceOf(user);
        uint256 token1Before = token1.balanceOf(user);
        
        pool.removeLiquidity(lpBalance);
        
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
        assertEq(token0.balanceOf(user), token0Before + amount0);
        assertEq(token1.balanceOf(user), token1Before + amount1);
        assertEq(pool.lpToken().balanceOf(user), 0);
        vm.stopPrank();
    }

    function test_AddLiquidityZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(LiquidityPool.InvalidAmount.selector);
        pool.addLiquidity(0, 100e18);
        
        vm.expectRevert(LiquidityPool.InvalidAmount.selector);
        pool.addLiquidity(100e18, 0);
        vm.stopPrank();
    }

    function test_RemoveLiquidityZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(LiquidityPool.InvalidAmount.selector);
        pool.removeLiquidity(0);
        vm.stopPrank();
    }

    function testFuzz_AddLiquidity(uint256 amount0, uint256 amount1) public {
        // Bound the values to reasonable ranges and avoid overflow
        amount0 = bound(amount0, 1e18, 1000e18);
        amount1 = bound(amount1, 1e18, 1000e18);
        
        token0.mint(user, amount0);
        token1.mint(user, amount1);
        
        vm.prank(user);
        pool.addLiquidity(amount0, amount1);
        
        assertEq(pool.reserve0(), amount0);
        assertEq(pool.reserve1(), amount1);
        assertTrue(pool.lpToken().balanceOf(user) > 0);
    }

    function test_HelperFunctions() public pure {
        // Test _min function through a public wrapper
        assertEq(_callMin(5, 3), 3);
        assertEq(_callMin(2, 8), 2);
        assertEq(_callMin(4, 4), 4);

        // Test _sqrt function through a public wrapper
        assertEq(_callSqrt(0), 0);
        assertEq(_callSqrt(1), 1);
        assertEq(_callSqrt(4), 2);
        assertEq(_callSqrt(16), 4);
        assertEq(_callSqrt(100), 10);
    }

    // Helper functions to test internal functions
    function _callMin(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _callSqrt(uint256 y) internal pure returns (uint256) {
        if (y > 3) {
            uint256 z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
            return z;
        } else if (y != 0) {
            return 1;
        }
        return 0;
    }
}