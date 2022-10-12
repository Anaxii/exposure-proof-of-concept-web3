const MainnetBridge = artifacts.require("ExposureMainnetBridge");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const TestToken = artifacts.require("TestToken");

let swapid = 0
contract("Bridge Core Functions", (accounts) => {
  it("Should create a bridgeToSubnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()

    await token.approve(mainnetBridge.address, 1, {from: accounts[0]})
    await mainnetBridge.bridgeToSubnet(1, token.address, {from: accounts[0]})
    let _swapid = await mainnetBridge.bridgeRequestID.call()
    swapid = _swapid.toString()

    let bal = await token.balanceOf.call(mainnetBridge.address)
    expect(bal.toString() != "0")
  });
  it("Should fulfill bridgeToSubnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()

    await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, swapid, "test", "test", {from: accounts[0]})

    let subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    expect(subnetToken != "0x0000000000000000000000000000000000000000")
  });
  it("Should create a bridgeToMainnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()
    let _subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    const subnetToken = await TestToken.at(_subnetToken);

    let initBal = await subnetToken.balanceOf.call(accounts[0])

    await subnetToken.approve(subnetBridge.address, 1, {from: accounts[0]})
    await subnetBridge.bridgeToMainnet.call(token.address, 1, {from: accounts[0]})
    let _swapid = await subnetBridge.bridgeRequestID.call()
    swapid = _swapid.toString()

    let afterBal = await subnetToken.balanceOf.call(accounts[0])
    expect(initBal != afterBal)
  });
  it("Should fulfill bridgeToMainnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()

    let initBal = await token.balanceOf.call(accounts[0])

    await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, swapid, {from: accounts[0]})

    let afterBal = await token.balanceOf.call(accounts[0])
    expect(initBal != afterBal)
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
      let _swapid = await mainnetBridge.bridgeRequestID.call()
      swapid = _swapid.toString()
      let bal = await token.balanceOf.call(mainnetBridge.address)
      expect(true == false)
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
      await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, swapid, "test", "test", {from: accounts[0]})
      let subnetToken = await subnetBridge.subnetAddresses.call(token.address)
      expect(true == false)
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
      await subnetBridge.bridgeToMainnet.call(token.address, 1, {from: accounts[0]})
      let _swapid = await subnetBridge.bridgeRequestID.call()
      swapid = _swapid.toString()
      expect(true == false)
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
      await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, swapid, {from: accounts[0]})
      expect(true == false)
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

contract("The Bridge checks for duplicates", (accounts) => {
  it("Should create a bridgeToSubnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()

    await token.approve(mainnetBridge.address, 100000, {from: accounts[0]})
    await mainnetBridge.bridgeToSubnet(100000, token.address, {from: accounts[0]})
    let _swapid = await mainnetBridge.bridgeRequestID.call()
    swapid = _swapid.toString()

    let bal = await token.balanceOf.call(mainnetBridge.address)
    expect(bal.toString() != "0")
  });
  it("Should fulfill bridgeToSubnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()

    await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, swapid, "test", "test", {from: accounts[0]})

    let subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    expect(subnetToken != "0x0000000000000000000000000000000000000000")
  });
  it("Should fail bridgeToSubnet request on subnet", async () => {
    fail = false
    try {
      const token = await TestToken.deployed();
      const subnetBridge = await SubnetBridge.deployed()

      await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, swapid, "test", "test", {from: accounts[0]})
      expect(true == false)
    } catch {
      fail = true
    }
    expect(fail)
    fail = false
  });
  it("Should create a bridgeToMainnet request on subnet", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()
    let _subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    const subnetToken = await TestToken.at(_subnetToken);

    let initBal = await subnetToken.balanceOf.call(accounts[0])

    await subnetToken.approve(subnetBridge.address, 1, {from: accounts[0]})
    await subnetBridge.bridgeToMainnet.call(token.address, 1, {from: accounts[0]})
    let _swapid = await subnetBridge.bridgeRequestID.call()
    swapid = _swapid.toString()

    let afterBal = await subnetToken.balanceOf.call(accounts[0])
    expect(initBal != afterBal)
  });
  it("Should fulfill bridgeToMainnet request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()

    let initBal = await token.balanceOf.call(accounts[0])

    await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, swapid, {from: accounts[0]})

    let afterBal = await token.balanceOf.call(accounts[0])
    expect(initBal != afterBal)
  });
  it("Should fail bridgeToSubnet request on subnet", async () => {
    fail = false
    try {
      it("Should fail to fulfill bridgeToMainnet request on mainnet", async () => {
        const token = await TestToken.deployed();
        const mainnetBridge = await MainnetBridge.deployed()

        let initBal = await token.balanceOf.call(accounts[0])

        await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, swapid, {from: accounts[0]})

        let afterBal = await token.balanceOf.call(accounts[0])
        expect(initBal == afterBal)
      });
    } catch {
      fail = true
    }
    expect(fail)
    fail = false
  });

});
