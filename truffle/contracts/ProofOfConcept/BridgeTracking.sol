// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract BridgeTracking {
    mapping(uint256 => bool) public bridgeRequestIsComplete;
    mapping(uint256 => BridgeTransaction) public requestedBridgeInfo;
    mapping(uint256 => BridgeTransaction) public completedBridgeInfo;

    uint256 public bridgeRequestID = 0;

    struct BridgeTransaction {
        uint256 id;
        address user;
        uint256 amount;
        address asset;
    }

    event BridgeToSubnet(address indexed user, address indexed asset, uint256 indexed amount, uint256 _bridgeRequestID, string name_, string symbol_);
    event BridgeToMainnet(address indexed user, address indexed asset, uint256 indexed amount, uint256 _bridgeRequestID, string name_, string symbol_);
}
