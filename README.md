# 🦄 Uniswap V3 Liquidity Manager

## 📖 Описание
Этот проект содержит смарт-контракты для управления ликвидностью на **Uniswap V3**.  
Контракт позволяет автоматически рассчитывать диапазон цен и добавлять ликвидность в заданный пул Uniswap V3.  
Проект также включает **моки (mock-контракты)** для удобного тестирования.

## 🚀 Функциональность
- **Добавление ликвидности** в Uniswap V3 с автоматическим расчетом диапазона.
- **Коррекция балансов** перед добавлением ликвидности (при необходимости выполняется частичный своп).
- **Обертка ETH в WETH** для совместимости с Uniswap V3.
- **Тесты на Hardhat**, покрывающие основные сценарии работы.

## 📂 Структура проекта
```
📦 uniswap-v3-liquidity-manager
 ┣ 📂 contracts
 ┃ ┣ 📜 UniV3LiquidityManager.sol  - Основной контракт менеджера ликвидности
 ┃ ┣ 📜 UniswapV3PoolMock.sol      - Мок-контракт пула Uniswap V3
 ┃ ┣ 📜 NonfungiblePositionManagerMock.sol - Мок-контракт менеджера позиций
 ┃ ┣ 📜 WETH9.sol                  - Контракт обернутого ETH (WETH)
 ┃ ┣ 📂 interfaces
 ┃ ┃ ┣ 📜 IUniswapV3Pool.sol        - Интерфейс пула Uniswap V3
 ┃ ┃ ┣ 📜 INonfungiblePositionManager.sol - Интерфейс менеджера позиций
 ┃ ┃ ┗ 📜 IERC20.sol                - Интерфейс стандарта ERC-20
 ┣ 📂 test
 ┃ ┣ 📜 UniswapV3LiquidityManager.test.js - Тесты для менеджера ликвидности
 ┣ 📜 hardhat.config.js  - Конфигурация Hardhat
 ┣ 📜 package.json       - Зависимости проекта
 ┣ 📜 README.md          - Этот файл
```

## 🛠 Установка и запуск

### 🔹 Установка зависимостей
```sh
npm install
```

### 🔹 Компиляция смарт-контрактов
```sh
npx hardhat compile
```

### 🔹 Запуск тестов
```sh
npx hardhat test
```

## 📜 Лицензия
Этот проект распространяется под лицензией **MIT**.


# 🦄 Uniswap V3 Liquidity Manager

## 📖 Description
This project contains smart contracts for managing liquidity on **Uniswap V3**.  
The contract allows automatic price range calculations and adding liquidity to a specified Uniswap V3 pool.  
The project also includes **mock contracts** for convenient testing.

## 🚀 Features
- **Adds liquidity** to Uniswap V3 with automatic range calculation.
- **Adjusts balances** before adding liquidity (performs partial swaps if necessary).
- **Wraps ETH into WETH** for compatibility with Uniswap V3.
- **Hardhat tests** covering key scenarios.

## 📂 Project Structure
```
📦 uniswap-v3-liquidity-manager
 ┣ 📂 contracts
 ┃ ┣ 📜 UniV3LiquidityManager.sol  - Main liquidity manager contract
 ┃ ┣ 📜 UniswapV3PoolMock.sol      - Mock contract for Uniswap V3 pool
 ┃ ┣ 📜 NonfungiblePositionManagerMock.sol - Mock contract for position manager
 ┃ ┣ 📜 WETH9.sol                  - Wrapped ETH (WETH) contract
 ┃ ┣ 📂 interfaces
 ┃ ┃ ┣ 📜 IUniswapV3Pool.sol        - Interface for Uniswap V3 pool
 ┃ ┃ ┣ 📜 INonfungiblePositionManager.sol - Interface for position manager
 ┃ ┃ ┗ 📜 IERC20.sol                - Standard ERC-20 interface
 ┣ 📂 test
 ┃ ┣ 📜 UniswapV3LiquidityManager.test.js - Tests for the liquidity manager
 ┣ 📜 hardhat.config.js  - Hardhat configuration
 ┣ 📜 package.json       - Project dependencies
 ┣ 📜 README.md          - This file
```

## 🛠 Installation & Setup

### 🔹 Install Dependencies
```sh
npm install
```

### 🔹 Compile Smart Contracts
```sh
npx hardhat compile
```

### 🔹 Run Tests
```sh
npx hardhat test
```

## 📜 License
This project is licensed under the **MIT** license.