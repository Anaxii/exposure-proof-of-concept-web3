// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Util/Ownable.sol";

contract PoCFaucet is Ownable {

    address[] public tokens;
    mapping(address => bool) public hasWithdrawn;

    constructor() {
        tokens[0] = 0x81aA662AA88fA2866dae2cd8F732CdDcC960B21a;
        tokens[1] = 0xbBaB816955660ff71F553bE0b942F51C83634cd2;
        tokens[2] = 0x1948EaB46Ff886190eBd50250EB486517e132F3B;
        tokens[3] = 0xf84A51797c6A9A4BFb8E7206AA246d887031399b;
        tokens[4] = 0x281D66d554D733DB0D03236ACAAe3746c2d3C2A8;
        tokens[5] = 0x803871f6BB32a9C1230cdc182002f8e058791A9A;
        tokens[6] = 0x72187342BC71CAd08FcCC361ff8336A684dd6883;
    }

    function withdraw() external {
        if (msg.sender != owner())
            require(!hasWithdrawn[msg.sender]);
        hasWithdrawn[msg.sender] = true;
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transfer(msg.sender, 1e19);
        }
    }
}
