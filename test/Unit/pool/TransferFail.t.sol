// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LiquidityPool} from "../../../src/pool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";

contract TransferFailTest is Test {
    LiquidityPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;
    
    function setUp() public {
        user = makeAddr("user");
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");
        pool = new LiquidityPool(address(token0), address(token1));

        // Initial liquidity
        token0.mint(address(this), 1000 ether);
        token1.mint(address(this), 1000 ether);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        pool.addLiquidity(100 ether, 100 ether);

        // Setup user
        token0.mint(user, 100 ether);
        token1.mint(user, 100 ether);
    }

    function test_RevertWhen_AddLiquidityWithFailedTransfer() public {
        token0.setShouldRevert(true);
        vm.startPrank(user);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);
        vm.expectRevert("MockERC20: transfer failed");
        pool.addLiquidity(10 ether, 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_RemoveLiquidityWithFailedTransfer() public {
        // First give user some LP tokens
        pool.addLiquidity(50 ether, 50 ether);
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        pool.lpToken().transfer(user, lpBalance);

        token0.setShouldRevert(true);
        vm.startPrank(user);
        pool.lpToken().approve(address(pool), lpBalance);
        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(lpBalance);
        vm.stopPrank();
    }

    function test_RevertWhen_AddLiquidityWithFailedTransferToken1() public {
        token1.setShouldRevert(true);
        vm.startPrank(user);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);
        vm.expectRevert("MockERC20: transfer failed");
        pool.addLiquidity(10 ether, 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_RemoveLiquidityWithFailedTransferToken1() public {
        // First give user some LP tokens
        pool.addLiquidity(50 ether, 50 ether);
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        pool.lpToken().transfer(user, lpBalance);

        // First transfer succeeds but second fails
        token1.setShouldRevert(true);
        vm.startPrank(user);
        pool.lpToken().approve(address(pool), lpBalance);
        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(lpBalance);
        vm.stopPrank();
    }

    function test_RevertWhen_RemoveLiquidityWithSequentialTokenFailure() public {
        // First give user some LP tokens
        pool.addLiquidity(50 ether, 50 ether);
        uint256 lpBalance = pool.lpToken().balanceOf(address(this));
        pool.lpToken().transfer(user, lpBalance);

        vm.startPrank(user);
        pool.lpToken().approve(address(pool), lpBalance);

        // Test token0 failure
        token0.setShouldRevert(true);
        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(lpBalance);

        // Reset token0 and test token1 failure
        token0.setShouldRevert(false);
        token1.setShouldRevert(true);
        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(lpBalance);
        vm.stopPrank();
    }

    function test_RevertWhen_AddLiquidityWithBothTokenFailure() public {
        // Test when token0 transfer succeeds but token1 fails
        vm.startPrank(user);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        // Make token1 fail after token0 succeeds
        token0.setShouldRevert(false);
        token1.setShouldRevert(true);

        vm.expectRevert("MockERC20: transfer failed");
        pool.addLiquidity(10 ether, 10 ether);
        vm.stopPrank();
    }

    function test_SuccessfulAddLiquidityTransfers() public {
        vm.startPrank(user);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        // Ensure both tokens succeed
        token0.setShouldRevert(false);
        token1.setShouldRevert(false);

        // This should succeed
        uint256 beforeBalance = pool.lpToken().balanceOf(user);
        pool.addLiquidity(10 ether, 10 ether);
        uint256 afterBalance = pool.lpToken().balanceOf(user);
        
        // Verify LP tokens were received
        assertGt(afterBalance, beforeBalance, "LP tokens should be minted");
        vm.stopPrank();
    }
}
