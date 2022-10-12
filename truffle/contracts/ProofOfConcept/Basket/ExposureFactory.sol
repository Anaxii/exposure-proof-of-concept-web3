// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "./ExposureBasket.sol";

contract ExposureFactory {
    event AssetBasketCreated(address tokenAddress);

    function deployNewAssetBasket(
        string memory name,
        string memory symbol,
        address usdc,
        address owner,
        address _XPSRAddress,
        address _exposureAsset
    ) public returns (address) {
        ExposureBasket t = new ExposureBasket(
            name,
            symbol,
            usdc,
            owner,
            _XPSRAddress,
            _exposureAsset
        );
        emit AssetBasketCreated(address(t));

        return address(t);
    }
}
