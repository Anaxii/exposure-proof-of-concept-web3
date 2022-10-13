const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const WAVAX = artifacts.require("WAVAX");
const USDC = artifacts.require("USDC");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const TokenC = artifacts.require("TokenC");
const TokenD = artifacts.require("TokenD");
const TokenE = artifacts.require("TokenE");
const ERC20 = artifacts.require("ERC20");
const ExposureBasket = artifacts.require("ExposureBasket");


async function setupDEX(accounts) {
  return new Promise(async (ok) => {
    await WAVAX.new()
    await USDC.new()
    let wavax = await WAVAX.deployed()
    let usdc = await USDC.deployed()

    await UniswapV2Factory.new(accounts[0], {from: accounts[0]})
    let factory = await UniswapV2Factory.deployed()

    await UniswapV2Router02.new(factory.address, wavax.address, {from: accounts[0]})
    let router = await UniswapV2Router02.deployed()
    await factory.createPair(wavax.address, usdc.address, {from: accounts[0]})
    let pair_address = await factory.getPair.call(wavax.address, usdc.address)
    await wavax.approve(router.address, BigInt(1000) * BigInt(10 ** 18))
    await usdc.approve(router.address, BigInt(10000) * BigInt(10 ** 18))
    let deadline = Math.floor((Date.now() + 200000) / 1000)

    await router.addLiquidity(
      wavax.address,
      usdc.address,
      BigInt(1000) * BigInt(10 ** 18),
      BigInt(10000) * BigInt(10 ** 18),
      BigInt(1000) * BigInt(10 ** 18),
      BigInt(10000) * BigInt(10 ** 18),
      accounts[0],
      deadline,
      {from: accounts[0]})
    ok({wavax, usdc, factory, router, pair_address})
  })
}

async function newTokens(accounts) {
  return new Promise(async (ok) => {
    await TokenA.new()
    await TokenB.new()
    await TokenC.new()
    await TokenD.new()
    await TokenE.new()
    let tokenA = await TokenA.deployed()
    let tokenB = await TokenB.deployed()
    let tokenC = await TokenC.deployed()
    let tokenD = await TokenD.deployed()
    let tokenE = await TokenE.deployed()
    ok({tokenA, tokenB, tokenC, tokenD, tokenE})
  })
}

async function setupSubnet(accounts) {
  return new Promise(async (ok) => {
    await SubnetBridge.new()
    let subnetBridge = await SubnetBridge.deployed()
    await SubnetOracle.new(subnetBridge.address)
    let subnetOracle = await SubnetOracle.deployed()
    let w = await subnetOracle.exposureSubnetBridgeManager.call()
    ok({subnetBridge, subnetOracle})
  })
}
const fmt = (val) => (BigInt(val) * BigInt(10**18)).toString()

let dex
let subnetBridge
let subnetOracle
let tokenA
let tokenB
let tokenC
let tokenD
let tokenE
let wavaxSubnet
let usdcSubnet
let tokenASubnet
let tokenBSubnet
let tokenCSubnet
let tokenDSubnet
let tokenESubnet
let basket
contract("Exposure Basket", (accounts) => {
  it("Should setup the dex", async () => {
    dex = await setupDEX(accounts)
  });
  it("Should setup the tokens", async () => {
    let sub = await newTokens(accounts)
    tokenA = sub.tokenA
    tokenB = sub.tokenB
    tokenC = sub.tokenC
    tokenD = sub.tokenD
    tokenE = sub.tokenE
  });
  it("Should setup the subnet", async () => {
    let sub = await setupSubnet(accounts)
    subnetOracle = sub.subnetOracle
    subnetBridge = sub.subnetBridge
  });
  it("Should setup the subnet tokens", async () => {
    await subnetBridge.bridgeToSubnet(dex.wavax.address, accounts[0], BigInt(100000000000) * BigInt(10 ** 18), 1, "WAVAX", "WAVAX")
    await subnetBridge.bridgeToSubnet(dex.usdc.address, accounts[0], BigInt(100000000000) * BigInt(10 ** 18), 2, "USDC", "USDC")
    await subnetBridge.bridgeToSubnet(tokenA.address, accounts[0], BigInt(1000000000) * BigInt(10 ** 18), 3, "Token A", "Token A")
    await subnetBridge.bridgeToSubnet(tokenB.address, accounts[0], BigInt(300000000) * BigInt(10 ** 18), 4, "Token B", "Token B")
    await subnetBridge.bridgeToSubnet(tokenC.address, accounts[0], BigInt(200000000) * BigInt(10 ** 18), 5, "Token C", "Token C")
    await subnetBridge.bridgeToSubnet(tokenD.address, accounts[0], BigInt(10000000) * BigInt(10 ** 18), 6, "Token D", "Token D")
    await subnetBridge.bridgeToSubnet(tokenE.address, accounts[0], BigInt(800000000) * BigInt(10 ** 18), 7, "Token E", "Token E")
    let w = await subnetBridge.subnetAddresses.call(dex.wavax.address)
    let u = await subnetBridge.subnetAddresses.call(dex.usdc.address)
    let a = await subnetBridge.subnetAddresses.call(tokenA.address)
    let b = await subnetBridge.subnetAddresses.call(tokenB.address)
    let c = await subnetBridge.subnetAddresses.call(tokenC.address)
    let d = await subnetBridge.subnetAddresses.call(tokenD.address)
    let e = await subnetBridge.subnetAddresses.call(tokenE.address)
    wavaxSubnet = await ERC20.at(w)
    usdcSubnet = await ERC20.at(u)
    tokenASubnet = await ERC20.at(a)
    tokenBSubnet = await ERC20.at(b)
    tokenCSubnet = await ERC20.at(c)
    tokenDSubnet = await ERC20.at(d)
    tokenESubnet = await ERC20.at(e)
  });
  it("Should set the initial prices", async () => {
    await subnetOracle.changeBridgeAddress(subnetBridge.address)
    await subnetOracle.updateMultiple(
      [
        dex.wavax.address,
        dex.usdc.address,
        tokenA.address,
        tokenB.address,
        tokenC.address,
        tokenD.address,
        tokenE.address
      ],
      [
        fmt(20),
        fmt(1),
        fmt(100),
        fmt(50),
        fmt(20),
        fmt(10),
        fmt(2)
      ]
    )
    await subnetOracle.updateMultipleMarketCap(
      [
        dex.wavax.address,
        dex.usdc.address,
        tokenA.address,
        tokenB.address,
        tokenC.address,
        tokenD.address,
        tokenE.address
      ],
      [
        fmt(20 * 100000000000),
        fmt(1 * 100000000000),
        fmt(100 * 1000000000),
        fmt(50 * 300000000),
        fmt(20 * 200000000),
        fmt(10 * 10000000),
        fmt(2 * 800000000)
      ]
    )
  });
  it("Create a new basket", async () => {
    await ExposureBasket.new("test", "test", accounts[0], subnetOracle.address, subnetBridge.address)
    basket = await ExposureBasket.deployed()
    await subnetBridge.updateAuthorizedTrader(basket.address, true)
  });
  it("Initialize the basket", async () => {
    await basket.updateBridge(subnetBridge.address)
    await basket.updateOracle(subnetOracle.address)
    await basket.startRebalance()
    await basket.addTokens([
      tokenASubnet.address,
      tokenBSubnet.address,
      tokenCSubnet.address,
      tokenDSubnet.address,
      tokenESubnet.address
    ])
    await basket.updateTokenMarketCap()
    await basket.updateTokenPortions()
    await basket.updateRemainingPortions()
    await basket.finalizeIndexPrice()
    let weight = await basket.getTokenWeights.call(0, tokenASubnet.address)
    expect(weight.toString() == "828500414250207125")
  });
  it("Mint shares", async () => {
    await tokenASubnet.approve(basket.address, fmt(20 * 100000000000))
    await tokenBSubnet.approve(basket.address, fmt(20 * 100000000000))
    await tokenCSubnet.approve(basket.address, fmt(20 * 100000000000))
    await tokenDSubnet.approve(basket.address, fmt(20 * 100000000000))
    await tokenESubnet.approve(basket.address, fmt(20 * 100000000000))
    await basket.mint(fmt(1), accounts[0])
    let bal = await basket.balanceOf(accounts[0])
    expect(bal == "1000000000000000000")
  });
  it("Should update the prices", async () => {
    await subnetOracle.changeBridgeAddress(subnetBridge.address)
    await subnetOracle.updateMultiple(
      [
        dex.wavax.address,
        dex.usdc.address,
        tokenA.address,
        tokenB.address,
        tokenC.address,
        tokenD.address,
        tokenE.address
      ],
      [
        fmt(20),
        fmt(1),
        fmt(100),
        fmt(50),
        fmt(15),
        fmt(10),
        fmt(2)
      ]
    )
    await subnetOracle.updateMultipleMarketCap(
      [
        dex.wavax.address,
        dex.usdc.address,
        tokenA.address,
        tokenB.address,
        tokenC.address,
        tokenD.address,
        tokenE.address
      ],
      [
        fmt(20 * 100000000000),
        fmt(1 * 100000000000),
        fmt(100 * 1000000000),
        fmt(50 * 300000000),
        fmt(15 * 200000000),
        fmt(10 * 10000000),
        fmt(2 * 800000000)
      ]
    )
  });
  it("First rebalance", async () => {
    await basket.startRebalance()
    await basket.updateTokenMarketCap()
    await basket.updateTokenPortions()
    await basket.updateRemainingPortions()

    const mint = async (_amount, _asset) => {
      console.log(_asset, _amount)
      await basket.mintUnderlying(_asset, _amount)
    }
    const burn = async (_amount, _asset) => {
      console.log(_asset, _amount)
      await basket.burnUnderlying(_asset, _amount)
    }
    const decide = async (val, token) => {
      val = BigInt(val)
      if (val > BigInt(0)) {
        await mint(val, token)
      } else {
        await burn(val * BigInt(-1), token)
      }
    }

    let toSell = await basket.getTokenSellAmount(1, tokenASubnet.address)
    let toBuy = await basket.getTokenBuyAmount(1, tokenASubnet.address)
    console.log(toSell.toString(), toBuy.toString(), (toBuy - toSell).toString(), typeof toBuy)
    await decide(toBuy - toSell, tokenASubnet.address)
    toSell = await basket.getTokenSellAmount(1, tokenBSubnet.address)
    toBuy = await basket.getTokenBuyAmount(1, tokenBSubnet.address)
    console.log(toSell.toString(), toBuy.toString(), (toBuy - toSell).toString())
    await decide(toBuy - toSell, tokenBSubnet.address)
    toSell = await basket.getTokenSellAmount(1, tokenCSubnet.address)
    toBuy = await basket.getTokenBuyAmount(1, tokenCSubnet.address)
    console.log(toSell.toString(), toBuy.toString(), (toBuy - toSell).toString())
    await decide(toBuy - toSell, tokenCSubnet.address)
    toSell = await basket.getTokenSellAmount(1, tokenDSubnet.address)
    toBuy = await basket.getTokenBuyAmount(1, tokenDSubnet.address)
    console.log(toSell.toString(), toBuy.toString(), (toBuy - toSell).toString())
    await decide(toBuy - toSell, tokenDSubnet.address)
    toSell = await basket.getTokenSellAmount(1, tokenESubnet.address)
    toBuy = await basket.getTokenBuyAmount(1, tokenESubnet.address)
    console.log(toSell.toString(), toBuy.toString(), (toBuy - toSell).toString())
    await decide(toBuy - toSell, tokenESubnet.address)
    await basket.finalizePortions()
    await basket.confirmFinalPortions()
    await basket.finalizeIndexPrice()
    let weight = await basket.getTokenWeights.call(1, tokenBSubnet.address)
    console.log(weight.toString())

    let portions = await basket.getTokenPortions.call(1, tokenBSubnet.address)
    console.log(portions.toString())
    // expect(weight.toString() == "828500414250207125")
  });
});
