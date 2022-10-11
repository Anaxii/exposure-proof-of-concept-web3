const MainnetBridge = artifacts.require("ExposureMainnetBridge");
const MainnetOracle = artifacts.require("ExposureMainnetOracle");
const SubnetBridge = artifacts.require("ExposureSubnetBridge");
const SubnetOracle = artifacts.require("ExposureSubnetOracle");
const TestToken = artifacts.require("TestToken");

contract("Bridge", (accounts) => {
  it("Should create a bridge request on mainnet", async () => {
    const token = await TestToken.deployed();
    const mainnetBridge = await MainnetBridge.deployed()
    token.approve.call(mainnetBridge.address, 1)

    // assert.equal(
    //   metaCoinEthBalance,
    //   2 * metaCoinBalance,
    //   "Library function returned unexpected function, linkage may be broken"
    // );
  });
  // it("should send coin correctly", async () => {
  //   const metaCoinInstance = await MetaCoin.deployed();
  //
  //   // Setup 2 accounts.
  //   const accountOne = accounts[0];
  //   const accountTwo = accounts[1];
  //
  //   // Get initial balances of first and second account.
  //   const accountOneStartingBalance = (
  //     await metaCoinInstance.getBalance.call(accountOne)
  //   ).toNumber();
  //   const accountTwoStartingBalance = (
  //     await metaCoinInstance.getBalance.call(accountTwo)
  //   ).toNumber();
  //
  //   // Make transaction from first account to second.
  //   const amount = 10;
  //   await metaCoinInstance.sendCoin(accountTwo, amount, { from: accountOne });
  //
  //   // Get balances of first and second account after the transactions.
  //   const accountOneEndingBalance = (
  //     await metaCoinInstance.getBalance.call(accountOne)
  //   ).toNumber();
  //   const accountTwoEndingBalance = (
  //     await metaCoinInstance.getBalance.call(accountTwo)
  //   ).toNumber();
  //
  //   assert.equal(
  //     accountOneEndingBalance,
  //     accountOneStartingBalance - amount,
  //     "Amount wasn't correctly taken from the sender"
  //   );
  //   assert.equal(
  //     accountTwoEndingBalance,
  //     accountTwoStartingBalance + amount,
  //     "Amount wasn't correctly sent to the receiver"
  //   );
  // });
});
