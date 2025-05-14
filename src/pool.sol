// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LPToken} from "./LPToken.sol";

/**
 * @title LiquidityPool
 * @dev استخر نقدینگی ساده با قابلیت mint/burn توکن LP و عملیات سواپ
 */
contract LiquidityPool {
    error InsufficientLiquidity();
    error InvalidAmount();
    error TransferFailed();

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    LPToken public immutable lpToken;

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        lpToken = new LPToken("LP Token", "LPT");
        lpToken.transferOwnership(address(this));
    }

    /// @notice افزودن نقدینگی به استخر و دریافت LP توکن
    function addLiquidity(uint256 amount0, uint256 amount1) external {
        if (amount0 == 0 || amount1 == 0) revert InvalidAmount();

        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        uint256 liquidity;
        if (reserve0 == 0 && reserve1 == 0) {
            // اولین تأمین‌کننده
            liquidity = _sqrt(amount0 * amount1);
        } else {
            // نسبت با ذخایر
            liquidity = _min(
                (amount0 * lpToken.totalSupply()) / reserve0,
                (amount1 * lpToken.totalSupply()) / reserve1
            );
        }

        if (liquidity == 0) revert InsufficientLiquidity();
        lpToken.mint(msg.sender, liquidity);

        reserve0 += amount0;
        reserve1 += amount1;
    }

    /// @notice برداشت نقدینگی توسط کاربر با سوزاندن LP
    function removeLiquidity(uint256 lpAmount) external {
        if (lpAmount == 0) revert InvalidAmount();

        uint256 totalSupply = lpToken.totalSupply();

        uint256 amount0 = (lpAmount * reserve0) / totalSupply;
        uint256 amount1 = (lpAmount * reserve1) / totalSupply;

        lpToken.burn(msg.sender, lpAmount);
        
        bool success0 = token0.transfer(msg.sender, amount0);
        if (!success0) revert TransferFailed();
        
        bool success1 = token1.transfer(msg.sender, amount1);
        if (!success1) revert TransferFailed();

        reserve0 -= amount0;
        reserve1 -= amount1;
    }

    /// @dev توابع داخلی کمکی
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

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
