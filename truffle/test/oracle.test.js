const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const WAVAX = artifacts.require("WAVAX");
const USDC = artifacts.require("USDC");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");

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

contract("Token and dex setup", (accounts) => {
  it("Should setup the dex", async () => {
    let dex = await setupDEX(accounts)
    let bal = dex.wavax.balanceOf.call(dex.pair_address)
    expect(bal.toString() != "0")
  });
});

contract("Test mainnet oracle", (accounts) => {
  let dex
  it("Update price", async () => {
    await MainnetOracle.new()
    let mainnetOracle = await MainnetOracle.deployed()
    dex = await setupDEX(accounts)
    await mainnetOracle.updateMultiple([dex.pair_address], [dex.wavax.address], [dex.usdc.address])
  });
  it("Get price", async () => {
    let mainnetOracle = await MainnetOracle.deployed()
    let price = await mainnetOracle.price(dex.pair_address)
    expect(price != "0")
  });
});
