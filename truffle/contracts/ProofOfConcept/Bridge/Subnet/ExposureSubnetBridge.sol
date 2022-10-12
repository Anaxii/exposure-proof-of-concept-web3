// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../Util/Ownable.sol";
import "../../../Util/Pausable.sol";
import "../../../Util/IERC20.sol";
import "./ExposureSubnetERC20.sol";
import "../BridgeTracking.sol";

contract ExposureSubnetBridge is Ownable, Pausable, BridgeTracking {

    mapping(address => address) public mainnetAddresses;
    mapping(address => address) public subnetAddresses;
    mapping(address => bool) public authorizedSubnetTrader;

    event SubnetTraderMint(address indexed account, address indexed token, uint256 indexed amount);
    event SubnetTraderBurn(address indexed account, address indexed token, uint256 indexed amount);

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function bridgeToSubnet(address asset, address user, uint256 amount, uint256 _swapID, string memory name_, string memory symbol_) public onlyOwner whenNotPaused returns (address subnetToken) {
        require(!bridgeRequestIsComplete[_swapID], "Swap already fulfilled");
        require(user != address(0));
        if (subnetAddresses[asset] == address(0)) {
            ExposureSubnetERC20 token = new ExposureSubnetERC20(name_, symbol_);
            subnetAddresses[asset] = address(token);
            mainnetAddresses[address(token)] = asset;
        }
        bridgeRequestIsComplete[_swapID] = true;
        ExposureSubnetERC20(subnetAddresses[asset]).mint(user, amount);
        completedBridgeInfo[_swapID] = BridgeTransaction(_swapID, user, amount, asset);
        emit BridgeToSubnet(user, asset, amount, _swapID, name_, symbol_);
        return subnetAddresses[asset];
    }

    function bridgeToMainnet(address asset, uint256 amount) public whenNotPaused returns (uint256) {
        bridgeRequestID++;
        ExposureSubnetERC20(subnetAddresses[asset]).transferFrom(msg.sender, address(this), amount);
        ExposureSubnetERC20(subnetAddresses[asset]).burn(address(this), amount);
        requestedBridgeInfo[bridgeRequestID - 1] = BridgeTransaction(bridgeRequestID - 1, msg.sender, amount, asset);
        emit BridgeToMainnet(msg.sender, asset, amount, bridgeRequestID - 1, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
        return bridgeRequestID - 1;
    }

    function updateAuthorizedTrader(address _account, bool status) external onlyOwner {
        authorizedSubnetTrader[_account] = status;
    }

    function burnAsset(address _token, uint256 _amount) public {
        require(authorizedSubnetTrader[msg.sender]);
        ExposureSubnetERC20(_token).transferFrom(msg.sender, address(this), _amount);
        ExposureSubnetERC20(_token).burn(address(this), _amount);
        emit SubnetTraderBurn(msg.sender, _token, _amount);
    }

    function mintAsset(address _token, uint256 _amount) public {
        require(authorizedSubnetTrader[msg.sender]);
        ExposureSubnetERC20(_token).mint(address(this), _amount);
        emit SubnetTraderMint(msg.sender, _token, _amount);
    }

}
