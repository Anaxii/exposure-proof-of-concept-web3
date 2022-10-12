// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IExposureSubnetBridge {
    function subnetAddresses(address mainnetAddress) external view returns (address subnetAddress);
}
