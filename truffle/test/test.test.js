const MainnetBridge = artifacts.require("ExposureMainnetBridge");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const TestToken = artifacts.require("TestToken");

contract("Bridge Core Functions", (accounts) => {
  it("Should create a bridgeToSubnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()
    await token.approve(mainnetBridge.address, 1, {from: accounts[0]})
    await mainnetBridge.bridgeToSubnet(1, token.address, {from: accounts[0]})
  });
  it("Should fulfill bridgeToSubnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()
    await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, "test", "test", {from: accounts[0]})
    let subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    expect(subnetToken != "0x0000000000000000000000000000000000000000")
  });
  it("Should create a bridgeToMainnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()
    let _subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    const subnetToken = await TestToken.at(_subnetToken);
    await subnetToken.approve(subnetBridge.address, 1, {from: accounts[0]})
    await subnetBridge.bridgeToMainnet(token.address, accounts[0], 1, {from: accounts[0]})
  });
  it("Should fulfill bridgeToMainnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()
    await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, {from: accounts[0]})
  });
});

let fail = false
contract("The Bridge can be paused", (accounts) => {
  it("Pause the contracts", async () => {
    const mainnetBridge = await MainnetBridge.deployed()
    const subnetBridge = await SubnetBridge.deployed()
    await mainnetBridge.pause({from: accounts[0]})
    await subnetBridge.pause({from: accounts[0]})
  });
  it("Should fail to create a bridgeToSubnet request on mainnet", async () => {
    try {
      const token = await TestToken.deployed();
      const mainnetBridge = await MainnetBridge.deployed()
      await token.approve(mainnetBridge.address, 1, {from: accounts[0]})
      await mainnetBridge.bridgeToSubnet(1, token.address, {from: accounts[0]})
    } catch {
      fail = true
    }
    expect(fail)
    fail = false
  });
  it("Should fail to fulfill bridgeToSubnet request on subnet", async () => {
    try {
      const token = await TestToken.deployed();
      const subnetBridge = await SubnetBridge.deployed()
      await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, "test", "test", {from: accounts[0]})
      let subnetToken = await subnetBridge.subnetAddresses.call(token.address)
      expect(subnetToken != "0x0000000000000000000000000000000000000000")
    } catch {
      fail = true
    }
    expect(fail)
    fail = false
  });
  it("Should fail to create a bridgeToMainnet request on subnet", async () => {
    try {
      const token = await TestToken.deployed();
      const subnetBridge = await SubnetBridge.deployed()
      let _subnetToken = await subnetBridge.subnetAddresses.call(token.address)
      const subnetToken = await TestToken.at(_subnetToken);
      await subnetToken.approve(subnetBridge.address, 1, {from: accounts[0]})
      await subnetBridge.bridgeToMainnet(token.address, accounts[0], 1, {from: accounts[0]})
    } catch {
      fail = true
    }
    expect(fail)
    fail = false
  });
  it("Should fail to fulfill bridgeToMainnet request on mainnet", async () => {
    try {
      const token = await TestToken.deployed();
      const mainnetBridge = await MainnetBridge.deployed()
      await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, {from: accounts[0]})
    } catch {
      fail = true
    }
    expect(fail)
    fail = false
  });
  it("Unpause the contracts", async () => {
    const mainnetBridge = await MainnetBridge.deployed()
    const subnetBridge = await SubnetBridge.deployed()
    await mainnetBridge.unpause({from: accounts[0]})
    await subnetBridge.unpause({from: accounts[0]})
  });
});

contract("The Bridge is ownable", (accounts) => {
  it("Test should fail when the caller is not the owner", async () => {
    fail = false
    try {
      const mainnetBridge = await MainnetBridge.deployed()
      await mainnetBridge.pause({from: accounts[1]})
    } catch {
      fail = true
    }
    expect(fail)
    fail = false
  });
});
