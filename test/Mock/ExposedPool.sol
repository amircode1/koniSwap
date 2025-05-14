// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LiquidityPool} from "../../src/pool.sol";

contract ExposedPool is LiquidityPool {
    constructor(address _token0, address _token1) LiquidityPool(_token0, _token1) {}

    function exposed_sqrt(uint256 y) public pure returns (uint256) {
        return _sqrt(y);
    }

    function exposed_min(uint256 a, uint256 b) public pure returns (uint256) {
        return _min(a, b);
    }
}
