pragma solidity ^0.8.0;

import "../Util/ERC20.sol";

contract MintableERC20 is ERC20 {

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {

    }

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }

}

contract ERC20Factory {
    event NewToken(address, string);

    function deployNewERC20Token(string memory name) public returns (address){
        MintableERC20 t = new MintableERC20(name, name);
        emit NewToken(address(t), name);
        return address(t);
    }

}

contract WAVAX is MintableERC20 {
    constructor() MintableERC20("Wrapped Avax", "wAVAX") {
        _mint(msg.sender, 100000000000 * 10**18);
    }
}

contract USDC is MintableERC20 {
    constructor() MintableERC20("Avax USDC", "USDC") {
        _mint(msg.sender, 100000000000 * 10**18);
    }
}

contract TokenA is MintableERC20 {
    constructor() MintableERC20("Token A", "A") {
        _mint(msg.sender, 1000000000 * 10**18);
    }
}

contract TokenB is MintableERC20 {
    constructor() MintableERC20("Token B", "B") {
        _mint(msg.sender, 300000000 * 10**18);
    }
}

contract TokenC is MintableERC20 {
    constructor() MintableERC20("Token C", "C") {
        _mint(msg.sender, 200000000 * 10**18);
    }
}

contract TokenD is MintableERC20 {
    constructor() MintableERC20("Token D", "D") {
        _mint(msg.sender, 10000000 * 10**18);
    }
}

contract TokenE is MintableERC20 {
    constructor() MintableERC20("Token E", "E") {
        _mint(msg.sender, 800000000 * 10**18);
    }
}
