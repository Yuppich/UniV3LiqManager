// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IUniswapV3Pool.sol";

contract UniswapV3PoolMock is IUniswapV3Pool {
    address public override token0;
    address public override token1;
    uint160 private currentSqrtPriceX96;
    int24 public constant override tickSpacing = 60;
    uint24 public constant override fee = 3000;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        currentSqrtPriceX96 = uint160(1 << 96); // Начальное значение sqrtPrice = 1.0
    }
    
    function slot0() external view override returns (
        uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool
    ) {
        // Для упрощения всегда возвращаем tick = 0
        return (currentSqrtPriceX96, 0, 0, 0, 0, 0, true);
    }

    function swap(
        address,       // recipient
        bool,          // zeroForOne
        int256,        // amountSpecified
        uint160,       // sqrtPriceLimitX96
        bytes calldata // data
    ) external pure override returns (int256, int256) {
        // Заглушка для свапа, ничего не выполняет
        return (0, 0);
    }
    
    function setCurrentSqrtPriceX96(uint160 newPrice) external {
        currentSqrtPriceX96 = newPrice;
    }
}
