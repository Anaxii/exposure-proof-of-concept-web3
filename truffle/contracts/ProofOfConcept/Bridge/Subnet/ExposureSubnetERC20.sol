// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../Util/Ownable.sol";
import "../../../Util/ERC20.sol";
import "../../../Avalanche/AllowListInterface.sol";

contract ExposureSubnetERC20 is ERC20, Ownable {
    constructor (string memory name_, string memory symbol_) ERC20(name_, symbol_) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(AllowListInterface(0x0200000000000000000000000000000000000002).readAllowList(recipient) == 1);
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
}
