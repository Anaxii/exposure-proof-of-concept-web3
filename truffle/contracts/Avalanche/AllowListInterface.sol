// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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
