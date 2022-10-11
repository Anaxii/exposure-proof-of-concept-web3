// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Util/Ownable.sol";
import "../../Util/Pausable.sol";
import "../../Util/IERC20Metadata.sol";

contract ExposureMainnetBridge is Ownable, Pausable {

    mapping(address => bool) public isAllowed;

    event BridgeToSubnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_);
    event BridgeToMainnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_);

    constructor() {
        isAllowed[msg.sender] = true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function bridgeToSubnet(uint256 amount, address asset) public whenNotPaused {
        require(isAllowed[msg.sender], "User is not KYC approved");
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        emit BridgeToSubnet(msg.sender, asset, amount, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
    }

    function bridgeToMainnet(address asset, address user, uint256 amount) public onlyOwner whenNotPaused {
        emit BridgeToMainnet(msg.sender, asset, amount, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
        IERC20(asset).transfer(user, amount);
    }

    function setAllowed(address user, bool status) public onlyOwner {
        isAllowed[user] = status;
    }
}
