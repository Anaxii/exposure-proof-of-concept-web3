// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Util/Ownable.sol";
import "../../Util/Pausable.sol";
import "../../Util/IERC20.sol";
import "./ExposureSubnetERC20.sol";

contract ExposureSubnetBridge is Ownable, Pausable {

    event BridgeToSubnet(address indexed user, address indexed assetMainnet, address indexed assetSubnet, uint256 amount, string name_, string symbol_);
    event BridgeToMainnet(address indexed user, address indexed assetMainnet, address indexed assetSubnet, uint256 amount, string name_, string symbol_);

    mapping(address => address) public mainnetAddresses;
    mapping(address => address) public subnetAddresses;

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function bridgeToSubnet(address asset, address user, uint256 amount, string memory name_, string memory symbol_) public onlyOwner whenNotPaused {
        if (subnetAddresses[asset] == address(0)) {
            ExposureSubnetERC20 token = new ExposureSubnetERC20(name_, symbol_);
            subnetAddresses[asset] = address(token);
            mainnetAddresses[address(token)] = asset;
        }
        ExposureSubnetERC20(subnetAddresses[asset]).mint(user, amount);
        emit BridgeToSubnet(user, asset, subnetAddresses[asset], amount, name_, symbol_);
    }

    function bridgeToMainnet(address asset, address user, uint256 amount) public whenNotPaused {
        ExposureSubnetERC20(subnetAddresses[asset]).transferFrom(user, address(this), amount);
        ExposureSubnetERC20(subnetAddresses[asset]).burn(address(this), amount);
        emit BridgeToMainnet(user, asset, subnetAddresses[asset], amount, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
    }

}
