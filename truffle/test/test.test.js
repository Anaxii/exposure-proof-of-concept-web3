const MainnetBridge = artifacts.require("ExposureMainnetBridge");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const TestToken = artifacts.require("TestToken");

contract("Bridge", (accounts) => {
  it("Should create a bridgeToSubnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()
    await token.approve(mainnetBridge.address, 1, { from: accounts[0] })
    await mainnetBridge.bridgeToSubnet(1, token.address, { from: accounts[0] })
  });
  it("Should fulfill bridgeToSubnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()
    await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, "test", "test", { from: accounts[0] })
    let subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    expect(subnetToken != "0x0000000000000000000000000000000000000000")
  });
  it("Should create a bridgeToMainnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()
    let _subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    const subnetToken = await TestToken.at(_subnetToken);
    await subnetToken.approve(subnetBridge.address, 1, { from: accounts[0] })
    await subnetBridge.bridgeToMainnet(token.address, accounts[0], 1, { from: accounts[0] })
  });
  it("Should fulfill bridgeToMainnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()
    await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, { from: accounts[0] })
  });
});
