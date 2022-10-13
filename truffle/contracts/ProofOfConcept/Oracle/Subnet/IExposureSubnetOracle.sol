// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IExposureSubnetOracle {
    function price(address asset) external returns (uint256);
    function marketCap(address asset) external returns (uint256);
}
