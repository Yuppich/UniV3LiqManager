// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Интерфейс пула Uniswap V3
/// @notice Определяет основные функции взаимодействия с пулом
interface IUniswapV3Pool {

    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function tickSpacing() external view returns (int24);
    function slot0() external view returns (
        uint160 sqrtPriceX96,  // Текущая цена sqrt(P) в формате Q64.96
        int24 tick,            // Текущий тик
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );

    /// @notice Выполняет своп токенов в пуле
    /// @param recipient Адрес, который получит токены после свопа
    /// @param zeroForOne Если true, меняет token0 на token1; если false, наоборот
    /// @param amountSpecified Количество токенов для свопа (если положительное — точное количество входа, если отрицательное — точное количество выхода)
    /// @param sqrtPriceLimitX96 Ограничение по цене в формате sqrt(P)
    /// @param data Дополнительные данные (можно использовать для flash swap)
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}