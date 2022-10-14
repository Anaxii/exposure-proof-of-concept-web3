// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IExposureMainnetBridge {
    function authorizedWithdraw(address _asset, uint256 _amount) external;
}
