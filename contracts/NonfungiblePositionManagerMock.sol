// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    function mint(MintParams calldata params) external payable returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
}

/// @title NonfungiblePositionManagerMock
/// @notice Минимальная реализация мока для NonfungiblePositionManager для тестирования
contract NonfungiblePositionManagerMock is INonfungiblePositionManager {
    uint256 public tokenCounter;
    uint128 private constant MOCK_LIQUIDITY = 1000;

    function mint(MintParams calldata params)
        external
        payable
        override
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        tokenId = tokenCounter;
        liquidity = MOCK_LIQUIDITY; // Фиктивная ликвидность
        amount0 = params.amount0Desired;
        amount1 = params.amount1Desired;
        unchecked { tokenCounter++; }
    }
}
