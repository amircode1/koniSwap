// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LiquidityPool} from "../../../src/pool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";

contract PoolTest is Test {
    LiquidityPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;
    
    function setUp() public {
        user = makeAddr("user");
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");
        pool = new LiquidityPool(address(token0), address(token1));

        // Initial setup with large amounts
        uint256 initialAmount = 10_000_000 ether;
        token0.mint(address(this), initialAmount);
        token1.mint(address(this), initialAmount);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
    }

    function test_RevertWhen_AddLiquidityTokenTransferFailure() public {
        uint256 amount0 = 100e18;
        uint256 amount1 = 100e18;

        token0.setShouldRevert(true);
        vm.expectRevert("MockERC20: transfer failed");
        pool.addLiquidity(amount0, amount1);
    }

    function test_RevertWhen_RemoveLiquidityTokenTransferFailure() public {
        // Add initial liquidity
        pool.addLiquidity(100e18, 100e18);

        // Get LP tokens
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        
        // Make token transfer fail
        token0.setShouldRevert(true);
        
        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(lpBalance);
    }

    function test_RevertWhen_RemoveLiquidityToken1TransferFailure() public {
        // Add initial liquidity
        pool.addLiquidity(100e18, 100e18);

        // Get LP tokens
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        
        // Make token1 transfer fail
        token1.setShouldRevert(true);
        
        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(lpBalance);
    }

    function test_RemoveLiquidity_SuccessfulTransfers() public {
        // Add initial liquidity
        uint256 initialAmount = 100e18;
        pool.addLiquidity(initialAmount, initialAmount);

        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        uint256 beforeBalance0 = token0.balanceOf(address(this));
        uint256 beforeBalance1 = token1.balanceOf(address(this));

        pool.removeLiquidity(lpBalance);

        assertGt(token0.balanceOf(address(this)), beforeBalance0);
        assertGt(token1.balanceOf(address(this)), beforeBalance1);
        assertEq(pool.lpToken().balanceOf(address(this)), 0);
    }

    function test_AddLiquidity_ProportionalAmounts() public {
        // Add initial liquidity
        pool.addLiquidity(100e18, 100e18);

        uint256 reserve0Before = pool.reserve0();
        uint256 reserve1Before = pool.reserve1();

        // Add more liquidity with same ratio
        pool.addLiquidity(50e18, 50e18);

        assertEq(pool.reserve0(), reserve0Before + 50e18);
        assertEq(pool.reserve1(), reserve1Before + 50e18);
    }

    function test_AddLiquidity_MinimumAmount() public {
        // Test with very small amounts
        uint256 smallAmount = 100; // Very small amount
        pool.addLiquidity(smallAmount, smallAmount);

        assertEq(pool.reserve0(), smallAmount);
        assertEq(pool.reserve1(), smallAmount);
        assertGt(pool.lpToken().balanceOf(address(this)), 0);
    }

    function test_RemoveLiquidity_MaxAmount() public {
        pool.addLiquidity(100e18, 100e18);
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        
        pool.removeLiquidity(lpBalance);
        
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
    }

    function test_AddLiquidity_WithZeroReserves() public {
        // First liquidity provider sets the ratio
        uint256 amount0 = 100e18;
        uint256 amount1 = 200e18;
        pool.addLiquidity(amount0, amount1);
        
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        assertEq(lpBalance, _sqrt(amount0 * amount1));
    }
    
    function test_AddLiquidity_WithExistingReserves() public {
        // First add some liquidity
        pool.addLiquidity(100e18, 100e18);
        uint256 initialLPBalance = pool.lpToken().balanceOf(address(this));
        
        // Add more liquidity with different ratio
        pool.addLiquidity(50e18, 60e18);
        
        // Should get LP tokens based on minimum ratio
        uint256 newLPBalance = pool.lpToken().balanceOf(address(this));
        assertLt(newLPBalance - initialLPBalance, _sqrt(50e18 * 60e18));
    }
    
    function test_RemoveLiquidity_PartialAmount() public {
        // Add initial liquidity
        pool.addLiquidity(100e18, 100e18);
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        
        // Remove half
        uint256 halfLP = lpBalance / 2;
        pool.removeLiquidity(halfLP);
        
        assertEq(pool.lpToken().balanceOf(address(this)), lpBalance - halfLP);
        assertEq(pool.reserve0(), 50e18);
        assertEq(pool.reserve1(), 50e18);
    }

    function test_AddLiquidity_ZeroAmountShouldRevert() public {
        token0.mint(address(this), 1e18);
        token1.mint(address(this), 1e18);

        token0.approve(address(pool), 1e18);
        token1.approve(address(pool), 1e18);

        pool.addLiquidity(1e18, 1e18); // add initial liquidity

        token0.mint(address(this), 1e18);
        token1.mint(address(this), 0); // 👈

        token0.approve(address(pool), 1e18);
        token1.approve(address(pool), 0);

        vm.expectRevert(LiquidityPool.InvalidAmount.selector); // ✅ not InsufficientLiquidity
        pool.addLiquidity(1e18, 0);
    }


    // Helper functions to test internal math functions
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
