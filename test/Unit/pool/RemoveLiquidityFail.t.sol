// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LiquidityPool} from "../../../src/pool.sol";
import {LPToken} from "../../../src/LPToken.sol"; 
import {MockERC20} from "../../Mock/MockERC20.sol";

contract RemoveLiquidityFailTest is Test {
    LiquidityPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;
    uint256 public constant INITIAL_LIQUIDITY = 100e18;

    function setUp() public {
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");
        pool = new LiquidityPool(address(token0), address(token1));
        user = makeAddr("user");

        // Provide initial liquidity
        token0.mint(address(this), INITIAL_LIQUIDITY);
        token1.mint(address(this), INITIAL_LIQUIDITY);
        token0.approve(address(pool), INITIAL_LIQUIDITY);
        token1.approve(address(pool), INITIAL_LIQUIDITY);
        pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        // Transfer some LP tokens to user for testing
        LPToken lpToken = pool.lpToken();
        uint256 userLPAmount = lpToken.balanceOf(address(this)) / 2;
        lpToken.transfer(user, userLPAmount);
    }

    function test_RevertWhen_Token0TransferFails() public {
        vm.startPrank(user);
        LPToken lpToken = pool.lpToken();
        uint256 userLPBalance = lpToken.balanceOf(user);
        lpToken.approve(address(pool), userLPBalance);

        token0.setShouldRevert(true);

        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(userLPBalance);
        vm.stopPrank();
    }

    function test_RevertWhen_Token1TransferFails() public {
        vm.startPrank(user);
        LPToken lpToken = pool.lpToken();
        uint256 userLPBalance = lpToken.balanceOf(user);
        lpToken.approve(address(pool), userLPBalance);

        token1.setShouldRevert(true);

        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(userLPBalance);
        vm.stopPrank();
    }

    function test_RevertWhen_BothTokenTransfersFail() public {
        vm.startPrank(user);
        LPToken lpToken = pool.lpToken();
        uint256 userLPBalance = lpToken.balanceOf(user);
        lpToken.approve(address(pool), userLPBalance);

        token0.setShouldRevert(true);
        token1.setShouldRevert(true);

        vm.expectRevert("MockERC20: transfer failed");
        pool.removeLiquidity(userLPBalance);
        vm.stopPrank();
    }

    

}
