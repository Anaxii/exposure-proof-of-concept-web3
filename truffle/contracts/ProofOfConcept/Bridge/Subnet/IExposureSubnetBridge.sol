// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IExposureSubnetBridge {
    function subnetAddresses(address mainnetAddress) external view returns (address);
    function burnAsset(address _token, uint256 _amount) external;
    function mintAsset(address _token, uint256 _amount) external;
}
