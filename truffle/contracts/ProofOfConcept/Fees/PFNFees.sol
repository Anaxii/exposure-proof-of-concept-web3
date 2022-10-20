contract PFNFees is Ownable {

    uint256 public rateDivisor = 1e18;
    mapping(uint256 => uint256) public feeTiers;
    mapping(address => uint256) public userFeeTier;
    mapping(address => bool) public authorizedSmartContracts;

    constructor() {
        authorizedSmartContracts[msg.sender] = true;
        feeTiers[0] = 30e15;
    }

    function calculateFee(address _user, uint256 _amount) external virtual view returns (uint256 fee, uint256 remaining) {
        uint256 _fee = _amount * feeTiers[userFeeTier[_user]] / rateDivisor;
        return (_fee, _amount - _fee);
    }

    function setFee(uint256 _tier, uint256 _rate) external onlyOwner {
        feeTiers[_tier] = _rate;
    }

    function setUserFeeTier(uint256 _tier, address _user) external {
        require(authorizedSmartContracts[msg.sender], "PFNdAppFees: Unauthorized");
        userFeeTier[_user] = _tier;
    }

    function authorizeSmartContract(address _smartContract, bool _status) external onlyOwner {
        authorizedSmartContracts[_smartContract] = _status;
    }

}

contract PFNdAppFees is PFNFees {

    mapping(uint256 => uint256) public dAppFeeTiers;
    mapping(address => uint256) public dAppFeeTier;

    constructor() {
        dAppFeeTiers[0] = 3e17;
    }

    function calculateFee(address _user, uint256 _amount, address _dApp, uint256 _dAppFee) external override view returns (uint256 fee, uint256 dAppFee) {
        uint256 _fee1 = _amount * feeTiers[userFeeTier[_user]] / rateDivisor;
        uint256 _fee2 = _dAppFee * dAppFeeTiers[dAppFeeTier[_dApp]] / rateDivisor;
        return (_fee1, _fee2);
    }

    function setdAppFee(uint256 _tier, uint256 _rate) external onlyOwner {
        dAppFeeTiers[_tier] = _rate;
    }

    function setdAppFeeTier(uint256 _tier, address _user) external {
        require(authorizedSmartContracts[msg.sender], "PFNdAppFees: Unauthorized");
        dAppFeeTier[_user] = _tier;
    }

}

interface IPFNFees {
    function rateDivisor() external view returns (uint256);
    function feeTiers(uint256 _tier) external view returns (uint256);
    function userFeeTier(address _user) external view returns (uint256);
    function calculateFee(address _user, uint256 _amount) external view returns (uint256 fee, uint256 remaining);
    function setUserFeeTier(uint256 _tier, address _user) external;
}

interface IPFNFeesAdmin is IPFNFees {
    function setUserFeeTier(uint256 _tier, address _user) external;
    function setFee(uint256 _tier, uint256 _rate) external;
    function authorizeSmartContract(address _smartContract, bool _status) external;
}

interface IPFNdAppFees {
    function rateDivisor() external view returns (uint256);
    function feeTiers(uint256 _tier) external view returns (uint256);
    function userFeeTier(address _user) external view returns (uint256);
    function calculateFee(address _user, uint256 _amount) external view returns (uint256 fee, uint256 remaining);
    function setUserFeeTier(uint256 _tier, address _user) external;
}

interface IPFNdAppFeesAdmin is IPFNdAppFees {
    function setdAppFeeTier(uint256 _tier, address _user) external;
    function setdAppFee(uint256 _tier, uint256 _rate) external;
    function authorizeSmartContract(address _smartContract, bool _status) external;
}
