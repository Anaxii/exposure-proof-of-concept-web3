// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Util/Ownable.sol";
import "./IExposureSubnetBridgeManager.sol";

contract ExposureSubnetOracle is Ownable {

    IExposureSubnetBridgeManager public exposureSubnetBridgeManager;
    mapping(address => uint256) public price;

    event UpdatedPrice(uint256 indexed price, address indexed subnetToken, address indexed mainnetToken);

    constructor(address bridgeManager) {
        exposureSubnetBridgeManager = IExposureSubnetBridgeManager(bridgeManager);
    }

    function updateMultiple(address[] memory tokens, uint256[] memory prices) external {
        require(tokens.length == prices.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            updatePrice(tokens[i], prices[i]);
        }
    }

    function updatePrice(address mainnetToken, uint256 _price) public onlyOwner returns (uint updatedPrice) {
        address subnetTokenAddress = exposureSubnetBridgeManager.subnetAddresses(mainnetToken);
        require(subnetTokenAddress != address(0), "ExposureSubnetOracle: Token has not bridged");
        price[subnetTokenAddress] = _price;
        emit UpdatedPrice(_price, subnetTokenAddress, mainnetToken);
        return _price;
    }
}
