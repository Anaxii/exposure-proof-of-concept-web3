const MainnetBridge = artifacts.require("ExposureMainnetBridge");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const TestToken = artifacts.require("TestToken");

module.exports = async function (deployer) {
  await deployer.deploy(MainnetBridge);
  await deployer.deploy(MainnetOracle);
  await deployer.deploy(SubnetBridge);
  let sBridge = await SubnetBridge.deployed()
  await deployer.deploy(SubnetOracle, sBridge.address);
  await deployer.deploy(TestToken);
};
