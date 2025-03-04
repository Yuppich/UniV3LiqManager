const { ethers } = require("hardhat");
const { expect } = require("chai");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers");

describe("UniV3LiquidityManager", function () {
  let owner, user;
  let positionManager, liquidityManager;
  let tokenA, tokenB, tokenC;
  let pool, poolNonStandard;

  // Функция расчета sqrtPriceX96
  function calculateSqrtPrice(price, decimalsA, decimalsB) {
    const priceBN = BigInt(price);
    const decimalsDiff = 10n ** BigInt(decimalsA - decimalsB);
    const adjustedPrice = priceBN * decimalsDiff;
    
    let sqrt = adjustedPrice;
    let approx = (sqrt + 1n) / 2n;
    while (approx < sqrt) {
      sqrt = approx;
      approx = (sqrt + adjustedPrice / sqrt) / 2n;
    }
    
    return (sqrt * (2n ** 96n)).toString();
  }

  before(async function () {
    [owner, user] = await ethers.getSigners();

    // Деплой токенов
    const TestToken = await ethers.getContractFactory("TestToken");
    tokenA = await TestToken.deploy("TokenA", "TKA", 18, ethers.parseEther("1000000"));
    tokenB = await TestToken.deploy("TokenB", "TKB", 6, ethers.parseUnits("1000000", 6));
    // Деплой токена с 8 decimal
    tokenC = await TestToken.deploy("TokenC", "TKC", 8, ethers.parseUnits("1000000", 8));

    // Деплой мока пула
    const PoolMock = await ethers.getContractFactory("UniswapV3PoolMock");
    pool = await PoolMock.deploy(tokenA.target, tokenB.target);
    poolNonStandard = await PoolMock.deploy(tokenA.target, tokenC.target);

    // Установка начальной цены (1 A = 1 B)
    await pool.setCurrentSqrtPriceX96(calculateSqrtPrice(1, 18, 6));
    await poolNonStandard.setCurrentSqrtPriceX96(calculateSqrtPrice(1, 18, 8));
    // Деплой PositionManager
    const PositionManagerMock = await ethers.getContractFactory("NonfungiblePositionManagerMock");
    positionManager = await PositionManagerMock.deploy();

    // Деплой LiquidityManager
    const LiquidityManager = await ethers.getContractFactory("UniV3LiquidityManager");
    liquidityManager = await LiquidityManager.deploy(positionManager.target);

    // Настройка балансов
    await tokenA.transfer(user.address, ethers.parseEther("1000"));
    await tokenB.transfer(user.address, ethers.parseUnits("1000", 6));
    await tokenC.transfer(user.address, ethers.parseUnits("100000", 8));
  });

  it("Корректно добавляет ликвидность", async function () {
    await pool.setCurrentSqrtPriceX96(calculateSqrtPrice(100, 18, 6));

    await tokenA.connect(user).approve(liquidityManager.target, ethers.parseEther("10"));
    await tokenB.connect(user).approve(liquidityManager.target, ethers.parseUnits("1000", 6));

    const tx = await liquidityManager.connect(user).addLiquidity(
      pool.target,
      ethers.parseEther("10"),
      ethers.parseUnits("1000", 6),
      100
    );

    await expect(tx).to.emit(liquidityManager, "LiquidityAdded");
  });

  it("Выполняет своп при дисбалансе", async function () {
    await pool.setCurrentSqrtPriceX96(calculateSqrtPrice(200, 18, 6));

    await tokenA.connect(user).approve(liquidityManager.target, ethers.parseEther("10"));

    const tx = await liquidityManager.connect(user).addLiquidity(
      pool.target,
      ethers.parseEther("10"),
      0,
      200
    );

    await expect(tx).to.emit(liquidityManager, "LiquidityAdded");
  });
  it("Должен вернуть ошибку при width >= 10000", async function () {
    await pool.setCurrentSqrtPriceX96(calculateSqrtPrice(1, 18, 6));

    await expect(
      liquidityManager.connect(user).addLiquidity(
        pool.target,
        ethers.parseEther("10"),
        ethers.parseUnits("10", 6),
        10000 // Превышение максимальной ширины
      )
    ).to.be.revertedWith("Слишком широкая позиция");
  });

  it("Должен вернуть ошибку при недостаточном балансе токенов", async function () {
    await pool.setCurrentSqrtPriceX96(calculateSqrtPrice(1, 18, 6));
  
    await expect(
      liquidityManager.connect(user).addLiquidity(
        pool.target,
        ethers.parseEther("10000"), // 10000 ETH > 1000 (баланс пользователя)
        ethers.parseUnits("10", 6),
        100
      )
    ).to.be.revertedWith("Balance too low"); // Изменяем ожидаемое сообщение
  });

  it("Должен обработать нулевую ширину (width = 0)", async function () {
    await pool.setCurrentSqrtPriceX96(calculateSqrtPrice(1, 18, 6));
  
    // Добавляем одобрение токенов
    await tokenA.connect(user).approve(liquidityManager.target, ethers.parseEther("10"));
    await tokenB.connect(user).approve(liquidityManager.target, ethers.parseUnits("10", 6));
  
    const tx = await liquidityManager.connect(user).addLiquidity(
      pool.target,
      ethers.parseEther("10"),
      ethers.parseUnits("10", 6),
      0
    );
  
    await expect(tx).to.emit(liquidityManager, "LiquidityAdded");
  });

  it("Должен корректно работать с нестандартными decimal (18 и 8)", async function () {
    await poolNonStandard.setCurrentSqrtPriceX96(calculateSqrtPrice(500, 18, 8));
  
    // Добавляем полное одобрение
    await tokenA.connect(user).approve(liquidityManager.target, ethers.MaxUint256);
    await tokenC.connect(user).approve(liquidityManager.target, ethers.MaxUint256);
  
    const tx = await liquidityManager.connect(user).addLiquidity(
      poolNonStandard.target,
      ethers.parseEther("10"),
      ethers.parseUnits("5000", 8),
      100
    );
  
    await expect(tx).to.emit(liquidityManager, "LiquidityAdded");
  });

  it("Должен вернуть ошибку при нулевых суммах", async function () {
    await expect(
      liquidityManager.connect(user).addLiquidity(
        pool.target,
        0,
        0, // Обе суммы нулевые
        100
      )
    ).to.be.revertedWith("Нулевые суммы");
  });
});