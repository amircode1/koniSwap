// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AggregatorV3Interface} from '../test/Mock/AggregatorV3Interface.sol';

/**
 * @title SwapCoin
 * @dev قرارداد سواپ بین دو توکن ERC20 با استفاده از اوراکل‌های قیمت Chainlink-style (Mock).
 */
contract SwapCoin {
    error InvalidToken();
    error InsufficientBalance();
    error TransferFailed();
    error InvalidAmount();
    error InvalidAddress();
    error InvalidTokenPair();
    error InvalidSwap();

    event Swap(
        address indexed sender,
        address indexed tokenFrom,
        address indexed tokenTo,
        uint256 amountIn,
        uint256 amountOut
    );

    /// @notice آدرس دو توکن قابل سواپ
    address public immutable tokenA;
    address public immutable tokenB;

    /// @notice اوراکل‌های قیمت برای هر توکن (با 8 رقم اعشار)
    AggregatorV3Interface public immutable priceFeedA;
    AggregatorV3Interface public immutable priceFeedB;

    /**
     * @dev تنظیم اولیه آدرس توکن‌ها و اوراکل‌ها
     */
    constructor(
        address _tokenA,
        address _tokenB,
        address _priceFeedA,
        address _priceFeedB
    ) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        priceFeedA = AggregatorV3Interface(_priceFeedA);
        priceFeedB = AggregatorV3Interface(_priceFeedB);
    }

    /**
     * @notice انجام عملیات سواپ بین دو توکن مشخص‌شده.
     * @param fromToken آدرسی از توکن ورودی
     * @param toToken آدرسی از توکن خروجی
     * @param amount مقدار ورودی به صورت واحد پایه توکن (مثلاً wei)
     */
    function swap(address fromToken, address toToken, uint256 amount) external {
        if (fromToken != tokenA && fromToken != tokenB) revert InvalidToken();
        if (toToken != tokenA && toToken != tokenB) revert InvalidToken();
        if (fromToken == toToken) revert InvalidTokenPair();
        if (amount == 0) revert InvalidAmount();
        if (msg.sender == address(0)) revert InvalidAddress();
        // انتقال توکن ورودی به قرارداد
        IERC20(fromToken).transferFrom(msg.sender, address(this), amount);

        // دریافت قیمت‌ها از اوراکل‌ها (با فرض اینکه 8 decimals هستند)
        uint256 priceFrom = _getPrice(fromToken);
        uint256 priceTo = _getPrice(toToken);

        // محاسبه مقدار قابل دریافت (amountOut = (amount * priceFrom) / priceTo)
        uint256 amountOut = (amount * priceFrom) / priceTo;
        
        if (amountOut == 0) revert InvalidSwap();

        uint256 toTokenBalance = IERC20(toToken).balanceOf(address(this));
        if (toTokenBalance < amountOut) revert InsufficientBalance();

        bool success = IERC20(toToken).transfer(msg.sender, amountOut);
        if (!success) revert TransferFailed();

        emit Swap(msg.sender, fromToken, toToken, amount, amountOut);
    }

    /**
     * @dev دریافت قیمت توکن از اوراکل متناظر آن.
     * @param token آدرس توکن مورد نظر
     * @return قیمت به صورت uint256 (با 8 رقم اعشار)
     */
    function _getPrice(address token) internal view returns (uint256) {
        AggregatorV3Interface priceFeed =
            token == tokenA ? priceFeedA : priceFeedB;

        (, int256 answer,,,) = priceFeed.latestRoundData();
        require(answer > 0, "Invalid oracle price");
        return uint256(answer);
    }
}
