// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {ExposedPool} from "../../Mock/ExposedPool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";

contract LiquidityMathTest is Test {
    ExposedPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;

    function setUp() public {
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");
        pool = new ExposedPool(address(token0), address(token1));

        token0.mint(address(this), 10000 ether);
        token1.mint(address(this), 10000 ether);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
    }

    function test_MinHelper() public view {
        assertEq(pool.exposed_min(5, 10), 5);
        assertEq(pool.exposed_min(10, 5), 5);
        assertEq(pool.exposed_min(5, 5), 5);
        assertEq(pool.exposed_min(0, 5), 0);
        assertEq(pool.exposed_min(5, 0), 0);
        assertEq(pool.exposed_min(0, 0), 0);
    }

    function test_SqrtWithEdgeCases() public view {
        // Test all cases in the _sqrt function:
        // 1. y = 0
        assertEq(pool.exposed_sqrt(0), 0, "sqrt(0) should be 0");
        // 2. y = 1 (y != 0 but y <= 3)
        assertEq(pool.exposed_sqrt(1), 1, "sqrt(1) should be 1");
        // 3. y = 2 (y != 0 but y <= 3)
        assertEq(pool.exposed_sqrt(2), 1, "sqrt(2) should be 1");
        // 4. y = 3 (y != 0 but y <= 3)
        assertEq(pool.exposed_sqrt(3), 1, "sqrt(3) should be 1");
        // 5. y = 4 (y > 3)
        assertEq(pool.exposed_sqrt(4), 2, "sqrt(4) should be 2");
        // 6. Large numbers
        assertEq(pool.exposed_sqrt(10000), 100, "sqrt(10000) should be 100");
    }

    function test_SqrtWithLargeValue() public view {
        // Test a large value that requires multiple iterations of the while loop
        uint256 value = type(uint128).max;  // Large enough to need multiple iterations
        uint256 result = pool.exposed_sqrt(value);
        // Verify the result is correct by checking that squaring it doesn't exceed the input
        // and squaring (result + 1) does exceed the input
        assert(result * result <= value);
        assert((result + 1) * (result + 1) > value);
    }

    function test_SqrtWithMultipleIterations() public view {
        // Test sqrt with a value that requires more iterations of the while loop
        // to cover all code paths in the _sqrt function
        uint256 value = 1000000;  // This will require multiple iterations
        uint256 result = pool.exposed_sqrt(value);
        
        // Verify the result by checking that squaring it doesn't exceed input
        // but squaring result+1 does exceed input
        assert(result * result <= value);
        assert((result + 1) * (result + 1) > value);
        
        // Verify against the known value
        assertEq(result, 1000);  // sqrt of 1,000,000 should be 1,000
    }

    function test_LiquidityCalculationNoTotalSupply() public {
        // Test the first liquidity provider case
        uint256 amount0 = 1000;
        uint256 amount1 = 2000;
        
        // Add initial liquidity
        pool.addLiquidity(amount0, amount1);

        uint256 expectedLiquidity = pool.exposed_sqrt(amount0 * amount1);
        assertEq(pool.lpToken().totalSupply(), expectedLiquidity);
    }

    function test_LiquidityCalculationWithExistingLiquidity() public {
        // Add initial liquidity
        pool.addLiquidity(1000 ether, 1000 ether);
        uint256 initialTotalSupply = pool.lpToken().totalSupply();

        // Add more liquidity with same ratio
        pool.addLiquidity(500 ether, 500 ether);

        uint256 expectedAdditionalLiquidity = (500 ether * initialTotalSupply) / 1000 ether;
        assertEq(pool.lpToken().totalSupply(), initialTotalSupply + expectedAdditionalLiquidity);
    }

    function test_LiquidityCalculationWithDifferentRatios() public {
        // Add initial liquidity
        pool.addLiquidity(1000 ether, 1000 ether);
        uint256 initialTotalSupply = pool.lpToken().totalSupply();

        // Add more liquidity with different ratios
        pool.addLiquidity(200 ether, 400 ether);  // 2x ratio for token1

        // Should use the minimum of the two proportions
        uint256 expectedLiquidity = (200 ether * initialTotalSupply) / 1000 ether;
        assertEq(pool.lpToken().totalSupply(), initialTotalSupply + expectedLiquidity);
    }

    function test_LiquidityWorkflow() public {
        // First add some initial liquidity
        uint256 amount0 = 1000;
        uint256 amount1 = 1000;
        pool.addLiquidity(amount0, amount1);
        
        // Calculate expected
        uint256 initialLiquidity = pool.exposed_sqrt(amount0 * amount1);
        assertEq(pool.lpToken().totalSupply(), initialLiquidity);
        
        // Add more liquidity
        uint256 add0 = 500;
        uint256 add1 = 500;
        pool.addLiquidity(add0, add1);
        
        uint256 expectedAdditionalLiquidity = pool.exposed_min(
            (add0 * initialLiquidity) / amount0,
            (add1 * initialLiquidity) / amount1
        );
        
        assertEq(pool.lpToken().totalSupply(), initialLiquidity + expectedAdditionalLiquidity);
    }
}
