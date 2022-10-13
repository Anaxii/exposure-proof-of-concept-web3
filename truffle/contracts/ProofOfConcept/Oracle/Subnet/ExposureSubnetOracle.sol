// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../Util/Ownable.sol";
import "../../Bridge/Subnet/IExposureSubnetBridge.sol";

contract ExposureSubnetOracle is Ownable {

    IExposureSubnetBridge public exposureSubnetBridgeManager;
    mapping(address => uint256) public price;
    mapping(address => uint256) public marketCap;

    event UpdatedPrice(uint256 indexed price, address indexed subnetToken, address indexed mainnetToken);
    event UpdatedMarketCap(uint256 indexed mcap, address indexed subnetToken, address indexed mainnetToken);

    constructor(address bridgeManager) {
        exposureSubnetBridgeManager = IExposureSubnetBridge(bridgeManager);
    }

    function updateMultiple(address[] memory tokens, uint256[] memory prices) external {
        require(tokens.length == prices.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            updatePrice(tokens[i], prices[i]);
        }
    }

    function updatePrice(address mainnetToken, uint256 _price) public onlyOwner returns (uint256) {
        address subnetTokenAddress = exposureSubnetBridgeManager.subnetAddresses(mainnetToken);
        require(subnetTokenAddress != address(0), "ExposureSubnetOracle: Token has not bridged");
        price[subnetTokenAddress] = _price;
        emit UpdatedPrice(_price, subnetTokenAddress, mainnetToken);
        return _price;
    }

    function updateMultipleMarketCap(address[] memory tokens, uint256[] memory mcaps) external {
        require(tokens.length == mcaps.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            updateMarketCap(tokens[i], mcaps[i]);
        }
    }

    function updateMarketCap(address mainnetToken, uint256 _mcap) public onlyOwner returns (uint256) {
        address subnetTokenAddress = exposureSubnetBridgeManager.subnetAddresses(mainnetToken);
        require(subnetTokenAddress != address(0), "ExposureSubnetOracle: Token has not bridged");
        marketCap[subnetTokenAddress] = _mcap;
        emit UpdatedPrice(_mcap, subnetTokenAddress, mainnetToken);
        return _mcap;
    }
}
