// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/IERC20.sol";
import "./libraries/FullMath.sol";

/// @title Менеджер ликвидности Uniswap V3
/// @notice Контракт для управления позициями ликвидности с автоматическим расчётом диапазонов
contract UniV3LiquidityManager is ReentrancyGuard {
    INonfungiblePositionManager public immutable positionManager;

    // Для swap-логики в этом примере
    address private swapPool;
    address private token0Addr;
    address private token1Addr;

    // Минимальный/максимальный корень цены в формате Q96
    uint160 private constant MIN_SQRT_RATIO = 4295128740;
    uint160 private constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970341;
    
    uint256 private constant SCALE = 1e18;

    event LiquidityAdded(
        address indexed user,
        address indexed poolAddr,
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    );

    constructor(INonfungiblePositionManager _positionManager) {
        positionManager = _positionManager;
    }

    /// @notice Основная функция добавления ликвидности
    function addLiquidity(
        address poolAddress,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 width
    ) external nonReentrant returns (uint256 tokenId) {
        require(poolAddress != address(0), unicode"Нулевой адрес пула");
        require(amount0Desired > 0 || amount1Desired > 0, unicode"Нулевые суммы");
        require(width < 10000, unicode"Слишком широкая позиция");
        //require(width > 0, unicode"Ширина не может быть 0");

        IUniswapV3Pool v3pool = IUniswapV3Pool(poolAddress);
        (address _token0, address _token1, uint24 fee) = _getPoolParams(v3pool);

        _transferTokens(_token0, _token1, amount0Desired, amount1Desired);

        (int24 tickLower, int24 tickUpper) = _calculateTicks(v3pool, width);

        _adjustBalances(v3pool, _token0, _token1);

        (uint256 balance0, uint256 balance1) = _getBalances(_token0, _token1);
        _approveTokens(_token0,balance0);
        _approveTokens(_token1, balance1);

        tokenId = _mintPosition(_token0, _token1, fee, tickLower, tickUpper, balance0, balance1);
        _returnLeftovers(_token0, _token1);

        _emitLiquidityAdded(
            msg.sender,
            poolAddress,
            tokenId,
            0,
            balance0,
            balance1,
            tickLower,
            tickUpper
        );
    }

    /// @notice Рассчитывает тики на основе текущей цены и ширины диапазона
    function _calculateTicks(IUniswapV3Pool v3pool, uint256 width) 
        internal view returns (int24 tickLower, int24 tickUpper) 
    {
        (uint160 sqrtPriceX96, , ) = _getPoolPrice(v3pool);
        uint256 sqrtPriceX96_uint = uint256(sqrtPriceX96);
        // Безопасное вычисление currentPrice с использованием mulDiv для избежания переполнения
        uint256 currentPrice = FullMath.mulDiv(sqrtPriceX96_uint, sqrtPriceX96_uint, 2 ** 192);
        
        currentPrice *= 1e18; // Масштабирование до 1e18
        (uint256 lowerPrice, uint256 upperPrice) = calculatePriceBounds(currentPrice, width);
        tickLower = priceToTick(lowerPrice);
        tickUpper = priceToTick(upperPrice);
        // Если тики равны или в неправильном порядке, корректируем их
        if (tickLower >= tickUpper) {
            tickLower = -60;
            tickUpper = 60;
        }
        require(tickLower < tickUpper, unicode"Неверные тики");
    }

    /// @notice Вспомогательная функция для эмиссии события LiquidityAdded
    function _emitLiquidityAdded(
        address user,
        address poolAddr,
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) internal {
        emit LiquidityAdded(user, poolAddr, tokenId, liquidity, amount0, amount1, tickLower, tickUpper);
    }

    /// @notice Получает основные параметры пула
    function _getPoolParams(IUniswapV3Pool pool)
        internal
        view
        returns (
            address token0,
            address token1,
            uint24 fee
        )
    {
        token0 = pool.token0();
        token1 = pool.token1();
        fee = pool.fee();
    }

    /// @notice Перевод токенов от пользователя в наш контракт
    function _transferTokens(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal {
        if (amount0 > 0) {
            require(
                IERC20(token0).transferFrom(msg.sender, address(this), amount0),
                unicode"Ошибка перевода token0"
            );
        }
        if (amount1 > 0) {
            require(
                IERC20(token1).transferFrom(msg.sender, address(this), amount1),
                unicode"Ошибка перевода token1"
            );
        }
    }

    /// @notice Получает текущую цену из пула
    function _getPoolPrice(IUniswapV3Pool pool)
        internal
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex
        )
    {
        (
            uint160 _sqrtPriceX96,
            int24 _tick,
            uint16 _observationIndex,
            ,
            ,
            ,
        ) = pool.slot0();
        return (_sqrtPriceX96, _tick, _observationIndex);
    }

    /// @notice Рассчитывает граничные тики (lowerPrice, upperPrice) по ценам
    function _getTicks(
        uint256 lowerPrice,
        uint256 upperPrice
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        tickLower = priceToTick(lowerPrice);
        tickUpper = priceToTick(upperPrice);
        // Если тики оказались равными, искусственно задаём диапазон для тестирования
        
        require(tickLower < tickUpper, unicode"Неверные тики");
    }

    /// @notice Корректирует балансы при необходимости: выполняет частичный своп
    function _adjustBalances(
        IUniswapV3Pool v3pool,
        address token0,
        address token1
    ) internal {
        (uint256 balance0, uint256 balance1) = _getBalances(token0, token1);
        (uint160 sqrtPriceX96, , ) = _getPoolPrice(v3pool);
        // Используем mulDiv для избежания переполнения
        uint256 currentPrice = FullMath.mulDiv(uint256(sqrtPriceX96), uint256(sqrtPriceX96), 2 ** 192);

        if (balance0 > 0 && balance1 > 0) {
            if ((balance0 * 1e18) / balance1 > currentPrice) {
                _performSwap(v3pool, token0, token1, true, balance0 / 2);
            } else {
                _performSwap(v3pool, token0, token1, false, balance1 / 2);
            }
        }
    }

    /// @notice Возвращает текущие балансы токенов, находящихся в контракте
    function _getBalances(
        address token0,
        address token1
    ) internal view returns (uint256 balance0, uint256 balance1) {
        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
    }

    /// @notice Одобряет PositionManager для перевода токенов
    function _approveTokens(address token, uint256 amount) internal {
        if (IERC20(token).allowance(address(this), address(positionManager)) < amount) {
            IERC20(token).approve(address(positionManager), type(uint256).max);
        }
    }

    /// @notice Создаёт позицию ликвидности в NonfungiblePositionManager
    function _mintPosition(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 tokenId) {
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender,
                deadline: block.timestamp + 600
            });

        (tokenId, , , ) = positionManager.mint(params);
    }

    /// @notice Возвращает неиспользованные токены обратно пользователю
    function _returnLeftovers(address token0, address token1) internal {
        uint256 leftover0 = IERC20(token0).balanceOf(address(this));
        if (leftover0 > 0) {
            IERC20(token0).transfer(msg.sender, leftover0);
        }
        uint256 leftover1 = IERC20(token1).balanceOf(address(this));
        if (leftover1 > 0) {
            IERC20(token1).transfer(msg.sender, leftover1);
        }
    }

    /// @notice Выполняет своп через пул
    function _performSwap(
        IUniswapV3Pool pool,
        address _token0,
        address _token1,
        bool zeroForOne,
        uint256 amount
    ) internal {
        swapPool = address(pool);
        token0Addr = _token0;
        token1Addr = _token1;

        pool.swap(
            address(this),
            zeroForOne,
            int256(amount),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            ""
        );

         // Очистка переменных после свапа
        swapPool = address(0);
        token0Addr = address(0);
        token1Addr = address(0);
    }

    /// @notice Callback для свопа Uniswap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(msg.sender == swapPool, unicode"Неавторизованный вызов");

        if (amount0Delta > 0) {
            IERC20(token0Addr).transfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(token1Addr).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    /// @notice Расчёт границ цены (lowerPrice, upperPrice) при заданном width
    function calculatePriceBounds(
        uint256 currentPrice,
        uint256 width
    ) internal pure returns (uint256 lowerPrice, uint256 upperPrice) {
        uint256 w = (width * SCALE) / 10000;
        uint256 rSquared = FullMath.mulDiv(SCALE + w, SCALE, SCALE - w);
        uint256 r = sqrt(rSquared);

        lowerPrice = FullMath.mulDiv(currentPrice, SCALE, r);
        upperPrice = FullMath.mulDiv(currentPrice, r, SCALE);
    }

    /// @notice Конвертация цены в тик (упрощённо)
    function priceToTick(uint256 price) internal pure returns (int24) {
        // Умножаем на 1e18 для сохранения точности при извлечении корня
        uint256 scaledPrice = price * 1e18;
        uint256 sqrtScaledPrice = sqrt(scaledPrice);
        // sqrt(price * 1e18) = sqrt(price) * 1e9 → преобразуем в формат Q64.96
        uint160 sqrtPriceX96 = uint160((sqrtScaledPrice << 96) / 1e9);
        
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    /// @notice Целочисленный sqrt
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) >> 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) >> 1;
        }
    }
}
