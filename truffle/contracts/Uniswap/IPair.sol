// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../Util/IERC20.sol";

interface IPair is IERC20 {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );
}
