const MainnetBridge = artifacts.require("ExposureMainnetBridge");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const TestToken = artifacts.require("TestToken");

const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const WAVAX = artifacts.require("WAVAX");
const USDC = artifacts.require("USDC");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const TokenC = artifacts.require("TokenC");
const TokenD = artifacts.require("TokenD");
const TokenE = artifacts.require("TokenE");
const feeToSetter = "0xAb41077bA83A35013534104Ac7ba7cA76e86828f";

module.exports = async function (deployer, network, accounts) {
  // bridge testing
  await deployer.deploy(MainnetBridge);
  await deployer.deploy(MainnetOracle);
  await deployer.deploy(SubnetBridge);
  let sBridge = await SubnetBridge.deployed()
  await deployer.deploy(SubnetOracle, sBridge.address);
  await deployer.deploy(TestToken);

  // oracle testing
  await deployer.deploy(USDC)
  await deployer.deploy(WAVAX)
  await deployer.deploy(TokenA)
  await deployer.deploy(TokenB)
  await deployer.deploy(TokenC)
  await deployer.deploy(TokenD)
  await deployer.deploy(TokenE)

  let wavax = await WAVAX.deployed()
  let usdc = await USDC.deployed()

  await deployer.deploy(UniswapV2Factory, accounts[0])
  let factory = await UniswapV2Factory.deployed()

  await deployer.deploy(UniswapV2Router02, factory.address, WAVAX.address);
  let router = await UniswapV2Router02.deployed()

  let mainnetBridge = await MainnetBridge.deployed()
  await deployer.deploy(MainnetOracle)
  await deployer.deploy(SubnetOracle, mainnetBridge.address)
};
