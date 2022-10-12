// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Util/Ownable.sol";
import "../../Util/Pausable.sol";
import "../../Util/IERC20Metadata.sol";
import "../BridgeTracking.sol";

contract ExposureMainnetBridge is Ownable, Pausable, BridgeTracking {

    mapping(address => bool) public isAllowed;

    constructor() {
        isAllowed[msg.sender] = true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function bridgeToSubnet(uint256 amount, address asset) public whenNotPaused returns (uint256) {
        require(isAllowed[msg.sender], "User is not KYC approved");
        require(amount > 0);
        bridgeRequestID++;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        requestedBridgeInfo[bridgeRequestID - 1] = BridgeTransaction(bridgeRequestID - 1, msg.sender, amount, asset);
        emit BridgeToSubnet(msg.sender, asset, amount, bridgeRequestID - 1, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
        return bridgeRequestID - 1;
    }

    function bridgeToMainnet(address asset, address user, uint256 amount, uint256 _swapID) public onlyOwner whenNotPaused returns (address) {
        require(!bridgeRequestIsComplete[_swapID]);
        require(user != address(0));
        bridgeRequestIsComplete[_swapID] = true;
        IERC20(asset).transfer(user, amount);
        completedBridgeInfo[_swapID] = BridgeTransaction(_swapID, user, amount, asset);
        emit BridgeToMainnet(msg.sender, asset, amount, _swapID, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
        return asset;
    }

    function setAllowed(address user, bool status) public onlyOwner {
        isAllowed[user] = status;
    }
}
