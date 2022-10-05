// SPDX-License-Identifier: UNLICENSED
import "./Ownable.sol";
import "./IERC20.sol";
import "./ERC20.sol";
import "./Pausable.sol";

pragma solidity ^0.8.0;

// mainnet
contract ExposureBridge is Ownable, Pausable {

    mapping(address => bool) public isAllowed;

    event BridgeToSubnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_);
    event BridgeToMainnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_);

    constructor() {
        isAllowed[msg.sender] = true;
    }

    function bridgeToSubnet(uint256 amount, address asset) public whenNotPaused {
        require(isAllowed[msg.sender], "User is not KYC approved");
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        emit BridgeToSubnet(msg.sender, asset, amount, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
    }

    function bridgeToMainnet(uint256 amount, address asset, address user) public onlyOwner whenNotPaused {
        emit BridgeToMainnet(msg.sender, asset, amount, IERC20Metadata(asset).name(), IERC20Metadata(asset).symbol());
        IERC20(asset).transfer(user, amount);
    }

    function setAllowed(address user, bool status) public onlyOwner {
        isAllowed[user] = status;
    }
}

contract testERC20 is ERC20, Ownable {
    constructor (string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 1000 * 1e18);
    }
}

//subnet
contract ExposureSubnetBridgeManager is Ownable, Pausable {

    event BridgeToSubnet(address indexed user, address indexed assetMainnet, address indexed assetSubnet, uint256 amount, string name_, string symbol_);
    event BridgeToMainnet(address indexed user, address indexed assetMainnet, address indexed assetSubnet, uint256 amount, string name_, string symbol_);

    mapping(address => address) public mainnetAddresses;
    mapping(address => address) public subnetAddresses;

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

contract ExposureSubnetERC20 is ERC20, Ownable {
    constructor (string memory name_, string memory symbol_) ERC20(name_, symbol_) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(AllowListInterface(0x0200000000000000000000000000000000000002).readAllowList(recipient) == 1);
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
}

// built in tx allow list @ 0x0200000000000000000000000000000000000002
interface AllowListInterface {
    // Set [addr] to have the admin role over the allow list
    function setAdmin(address addr) external;

    // Set [addr] to be enabled on the allow list
    function setEnabled(address addr) external;

    // Set [addr] to have no role over the allow list
    function setNone(address addr) external;

    // Read the status of [addr]
    function readAllowList(address addr) external view returns (uint256);
}
