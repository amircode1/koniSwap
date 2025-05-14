// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LiquidityPool} from "../../src/pool.sol";

contract TestLiquidityPool is LiquidityPool {
    constructor(address token0_, address token1_) LiquidityPool(token0_, token1_) {}

    function min(uint x, uint y) external pure returns (uint z) {
        return _min(x, y);
    }

    function sqrt(uint y) external pure returns (uint z) {
        return _sqrt(y);
    }
}
