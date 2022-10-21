// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Util/Ownable.sol";

contract SubnetSubaccount is Ownable {

    mapping(address => address) public subAccountOwner;
    mapping(address => address[]) public subAccounts;
    uint256 public subAccountLimit = 10;

    event NewSubAccount(address indexed subAccount, address indexed owner);

    function addSubAccount(address _subAccount) external {
        require(subAccounts[msg.sender].length < subAccountLimit);
        subAccountOwner[_subAccount] = msg.sender;
        subAccounts[msg.sender].push(_subAccount);
        emit NewSubAccount(_subAccount, msg.sender);
    }

    function changeSubAccountLimit(uint256 _limit) external onlyOwner {
        subAccountLimit = _limit;
    }
}
