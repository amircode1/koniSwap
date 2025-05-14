// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {ExposedPool} from "../../Mock/ExposedPool.sol";
import {MockERC20} from "../../Mock/MockERC20.sol";

contract InternalFunctionsTest is Test {
    ExposedPool public pool;
    MockERC20 public token0;
    MockERC20 public token1;

    function setUp() public {
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");
        pool = new ExposedPool(address(token0), address(token1));
    }

    function testSqrtSpecialCases() public {
        // Test y = 0
        assertEq(pool.exposed_sqrt(0), 0, "sqrt(0) should be 0");

        // Test y = 1
        assertEq(pool.exposed_sqrt(1), 1, "sqrt(1) should be 1");

        // Test y = 2
        assertEq(pool.exposed_sqrt(2), 1, "sqrt(2) should be 1");

        // Test y = 3
        assertEq(pool.exposed_sqrt(3), 1, "sqrt(3) should be 1");

        // Test y = 4 (first case where y > 3)
        assertEq(pool.exposed_sqrt(4), 2, "sqrt(4) should be 2");
    }

    function testMinFunction() public {
        assertEq(pool.exposed_min(5, 10), 5, "min(5,10) should be 5");
        assertEq(pool.exposed_min(10, 5), 5, "min(10,5) should be 5");
        assertEq(pool.exposed_min(5, 5), 5, "min(5,5) should be 5");
        assertEq(pool.exposed_min(0, 5), 0, "min(0,5) should be 0");
        assertEq(pool.exposed_min(5, 0), 0, "min(5,0) should be 0");
        assertEq(pool.exposed_min(0, 0), 0, "min(0,0) should be 0");
    }
}
