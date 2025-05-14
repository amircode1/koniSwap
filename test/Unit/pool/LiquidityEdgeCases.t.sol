// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LiquidityPool} from "../../../src/pool.sol";
import {ExposedPool} from "../../mocks/ExposedPool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";

contract LiquidityEdgeCasesTest is Test {
    ExposedPool public pool;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    address public user = address(1);
    address public user2 = address(2);

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);
        pool = new ExposedPool(address(tokenA), address(tokenB));

        // Initial mint for users
        tokenA.mint(user, 1000 ether);
        tokenB.mint(user, 1000 ether);
        tokenA.mint(user2, 1000 ether);
        tokenB.mint(user2, 1000 ether);

        vm.startPrank(user);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function test_AddLiquidity_MinimalAmounts() public {
        vm.startPrank(user);
        // Test with smallest possible amounts that won't result in zero liquidity
        pool.addLiquidity(2, 2);
        assertEq(pool.reserve0(), 2);
        assertEq(pool.reserve1(), 2);
        vm.stopPrank();
    }

    function test_AddLiquidity_MaxAmounts() public {
        // Test with very large amounts close to uint256 max
        uint256 largeAmount = type(uint256).max / 2;
        tokenA.mint(user, largeAmount);
        tokenB.mint(user, largeAmount);

        vm.startPrank(user);
        pool.addLiquidity(largeAmount, largeAmount);
        assertEq(pool.reserve0(), largeAmount);
        assertEq(pool.reserve1(), largeAmount);
        vm.stopPrank();
    }

    function test_RemoveLiquidity_VerySmallAmount() public {
        vm.startPrank(user);
        // Add initial liquidity
        pool.addLiquidity(100 ether, 100 ether);
        uint256 lpBalance = pool.lpToken().balanceOf(user);
        
        // Remove very small amount of liquidity
        uint256 smallAmount = 1;
        pool.removeLiquidity(smallAmount);
        
        assertLt(pool.reserve0(), 100 ether);
        assertLt(pool.reserve1(), 100 ether);
        assertEq(pool.lpToken().balanceOf(user), lpBalance - smallAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_AddLiquidity_ExtremelyImbalancedRatio() public {
        vm.startPrank(user);
        // First add balanced liquidity
        pool.addLiquidity(100 ether, 100 ether);
        
        // Try to add extremely imbalanced amounts
        vm.expectRevert(LiquidityPool.InsufficientLiquidity.selector);
        pool.addLiquidity(1000 ether, 1);
        vm.stopPrank();
    }

    function test_AddLiquidity_SequentialSmallAdds() public {
        vm.startPrank(user);
        // Add multiple small amounts sequentially
        for (uint256 i = 1; i <= 5; i++) {
            pool.addLiquidity(i, i);
            assertEq(pool.reserve0(), (i * (i + 1)) / 2);
            assertEq(pool.reserve1(), (i * (i + 1)) / 2);
        }
        vm.stopPrank();
    }

    function test_AddLiquidity_MultipleProviders() public {
        // Test with multiple liquidity providers adding different amounts
        vm.prank(user);
        pool.addLiquidity(50 ether, 50 ether);

        vm.prank(user2);
        pool.addLiquidity(100 ether, 100 ether);

        assertEq(pool.reserve0(), 150 ether);
        assertEq(pool.reserve1(), 150 ether);
    }

    function test_RemoveLiquidity_AllUserSequentially() public {
        vm.startPrank(user);
        pool.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        pool.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        uint256 user1LPBalance = pool.lpToken().balanceOf(user);
        uint256 user2LPBalance = pool.lpToken().balanceOf(user2);

        vm.prank(user);
        pool.removeLiquidity(user1LPBalance);

        vm.prank(user2);
        pool.removeLiquidity(user2LPBalance);

        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
    }

    function test_Math_SqrtRoundingEdgeCases() public {
        uint256[] memory testCases = new uint256[](7);
        testCases[0] = 0;  // Should return 0
        testCases[1] = 1;  // Should return 1
        testCases[2] = 2;  // Should return 1
        testCases[3] = 3;  // Should return 1
        testCases[4] = 4;  // Should return 2
        testCases[5] = type(uint256).max;  // Should handle max value
        testCases[6] = 1000000;  // Large but not extreme value

        uint256[] memory expectedResults = new uint256[](7);
        expectedResults[0] = 0;
        expectedResults[1] = 1;
        expectedResults[2] = 1;
        expectedResults[3] = 1;
        expectedResults[4] = 2;
        expectedResults[5] = 340282366920938463463374607431768211455;  // Approximate sqrt of max uint256
        expectedResults[6] = 1000;

        for (uint256 i = 0; i < testCases.length; i++) {
            assertEq(
                pool.exposed_sqrt(testCases[i]),
                expectedResults[i],
                "Sqrt calculation mismatch"
            );
        }
    }

    function test_RevertWhen_RemoveAllLiquidityThenAdd() public {
        vm.startPrank(user);
        pool.addLiquidity(100 ether, 100 ether);
        uint256 lpBalance = pool.lpToken().balanceOf(user);
        pool.removeLiquidity(lpBalance);

        // After removing all liquidity, adding small amounts should work
        // as if it's initial liquidity
        pool.addLiquidity(1 ether, 1 ether);
        assertEq(pool.reserve0(), 1 ether);
        assertEq(pool.reserve1(), 1 ether);
        vm.stopPrank();
    }
}
