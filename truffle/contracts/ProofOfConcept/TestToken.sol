// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Util/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("test", "test") {
        _mint(msg.sender, 1000 * 1e18);
    }
}
