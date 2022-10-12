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

contract("requestedBridgeInfo and completedBridgeInfo info is accurate for bridge transactions", (accounts) => {
  it("bridgeToSubnet request on mainnet tracking is equal to the request input", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()

    await token.approve(mainnetBridge.address, 1, {from: accounts[0]})
    await mainnetBridge.bridgeToSubnet(1, token.address, {from: accounts[0]})
    let _swapid = await mainnetBridge.bridgeRequestID.call()
    swapid = _swapid.toString()
    console.log(swapid)

    let info = await mainnetBridge.requestedBridgeInfo.call(Number(swapid) - 1)
    console.log(swapid)

    expect(info.id.toString() == (Number(swapid) - 1).toString() && info.user == accounts[0] && info.amount.toString() == "1" && info.asset == token.address)
  });
  it("Should fulfill bridgeToSubnet request on subnet and accurately save the input data into completed requests", async () => {
    console.log(swapid)

    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()

    await subnetBridge.bridgeToSubnet(token.address, accounts[0], 1, (Number(swapid) - 1).toString(), "test", "test", {from: accounts[0]})

    let info = await subnetBridge.completedBridgeInfo.call(Number(swapid) - 1)
    expect(info.id.toString() == (Number(swapid) - 1).toString() && info.user == accounts[0] && info.amount.toString() == "1" && info.asset == token.address)
  });
  it("Should verify bridgeTransactionID is marked as complete", async () => {
    const subnetBridge = await SubnetBridge.deployed()
    let val = await subnetBridge.bridgeRequestIsComplete.call((Number(swapid) - 1).toString())
    expect(val)
  });
  it("Should create a bridgeToMainnet request on subnet and accurately save the input data into completed requests", async () => {
    const token = await TestToken.deployed();
    const subnetBridge = await SubnetBridge.deployed()
    let _subnetToken = await subnetBridge.subnetAddresses.call(token.address)
    const subnetToken = await TestToken.at(_subnetToken);

    await subnetToken.approve(subnetBridge.address, 1, {from: accounts[0]})
    await subnetBridge.bridgeToMainnet(token.address, 1, {from: accounts[0]})
    let _swapid = await subnetBridge.bridgeRequestID.call()
    swapid = _swapid.toString()

    let info = await subnetBridge.requestedBridgeInfo.call(Number(swapid) - 1)
    expect(info.id.toString() == (Number(swapid) - 1).toString() && info.user == accounts[0] && info.amount.toString() == "1" && info.asset == token.address)
  });
  it("Should fulfill bridgeToMainnet request on mainnet and accurately save the input data into completed requests", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()

    await mainnetBridge.bridgeToMainnet(token.address, accounts[0], 1, swapid, {from: accounts[0]})

    let info = await mainnetBridge.completedBridgeInfo.call(Number(swapid) - 1)
    expect(info.id.toString() == (Number(swapid) - 1).toString() && info.user == accounts[0] && info.amount.toString() == "1" && info.asset == token.address)
  });
  it("Should verify bridgeTransactionID is marked as complete ", async () => {
    const mainnetBridge = await MainnetBridge.deployed()
    let val = await mainnetBridge.bridgeRequestIsComplete.call((Number(swapid) - 1).toString())
    expect(val)
  });
});
