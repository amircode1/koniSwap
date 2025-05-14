// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LPToken} from "../../../src/LPToken.sol";
import {LiquidityPool} from "../../../src/pool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LPTokenIntegrationTest is Test {
    LPToken public lpToken;
    LiquidityPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;
    address public liquidityProvider;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        user = makeAddr("user");
        liquidityProvider = makeAddr("liquidityProvider");

        // Deploy mock tokens
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");

        // Deploy pool
        pool = new LiquidityPool(address(token0), address(token1));
        lpToken = pool.lpToken();

        // Setup initial token balances
        token0.mint(liquidityProvider, 1000e18);
        token1.mint(liquidityProvider, 1000e18);
        token0.mint(user, 1000e18);
        token1.mint(user, 1000e18);

        // Approve pool for liquidity provider
        vm.startPrank(liquidityProvider);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        // Approve pool for user
        vm.startPrank(user);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function test_PoolLPTokenIntegration() public {
        // Add initial liquidity
        vm.startPrank(liquidityProvider);
        pool.addLiquidity(500e18, 500e18);
        vm.stopPrank();

        uint256 lpBalance = lpToken.balanceOf(liquidityProvider);
        assertTrue(lpBalance > 0, "Should have received LP tokens");
        assertEq(lpToken.owner(), address(pool), "Pool should own LP token");

        // Transfer LP tokens
        vm.prank(liquidityProvider);
        lpToken.transfer(user, lpBalance / 2);
        assertEq(lpToken.balanceOf(user), lpBalance / 2, "Transfer failed");

        // Remove liquidity with transferred tokens
        uint256 token0Before = token0.balanceOf(user);
        uint256 token1Before = token1.balanceOf(user);

        vm.prank(user);
        pool.removeLiquidity(lpBalance / 2);

        assertTrue(
            token0.balanceOf(user) > token0Before,
            "Should have received token0"
        );
        assertTrue(
            token1.balanceOf(user) > token1Before,
            "Should have received token1"
        );
    }

    function test_PoolLPTokenOwnership() public {
        // Verify pool owns LP token
        assertEq(lpToken.owner(), address(pool), "Pool should own LP token");

        // Try to mint directly (should fail)
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        lpToken.mint(user, 1000e18);

        // Add liquidity to get LP tokens properly
        vm.prank(liquidityProvider);
        pool.addLiquidity(500e18, 500e18);

        uint256 lpBalance = lpToken.balanceOf(liquidityProvider);
        assertTrue(lpBalance > 0, "Should have received LP tokens");
    }

    function test_MultipleProvidersAndRemovals() public {
        // First provider adds liquidity
        vm.prank(liquidityProvider);
        pool.addLiquidity(500e18, 500e18);
        uint256 firstProviderBalance = lpToken.balanceOf(liquidityProvider);

        // Second provider adds liquidity
        vm.prank(user);
        pool.addLiquidity(300e18, 300e18);
        uint256 secondProviderBalance = lpToken.balanceOf(user);

        // Both remove liquidity
        vm.prank(liquidityProvider);
        pool.removeLiquidity(firstProviderBalance);

        vm.prank(user);
        pool.removeLiquidity(secondProviderBalance);

        // Verify final states
        assertEq(lpToken.balanceOf(liquidityProvider), 0, "Should have no LP tokens left");
        assertEq(lpToken.balanceOf(user), 0, "Should have no LP tokens left");
        assertEq(lpToken.totalSupply(), 0, "Total supply should be 0");
    }

    function test_LPTokenApprovalWithPool() public {
        // Add initial liquidity
        vm.prank(liquidityProvider);
        pool.addLiquidity(500e18, 500e18);
        uint256 lpBalance = lpToken.balanceOf(liquidityProvider);

        // Approve user to spend LP tokens
        vm.prank(liquidityProvider);
        lpToken.approve(user, lpBalance);

        // User tries to use transferFrom to get LP tokens
        vm.prank(user);
        lpToken.transferFrom(liquidityProvider, user, lpBalance);

        // User removes liquidity with transferred tokens
        vm.prank(user);
        pool.removeLiquidity(lpBalance);

        assertEq(lpToken.balanceOf(user), 0, "Should have no LP tokens left");
        assertTrue(
            token0.balanceOf(user) > 1000e18,
            "Should have received extra token0"
        );
    }
}