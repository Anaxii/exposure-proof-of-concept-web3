// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "../../Util/Ownable.sol";
import "../../Util/Manageable.sol";
import "../../Util/Strings.sol";
import "../../Util/Context.sol";
import "../../Util/IERC20.sol";
import "../../Uniswap/IPair.sol";
import "../../Uniswap/IUniswapV2Router01.sol";
import "../../Uniswap/IUniswapV2Factory.sol";
import "../../Util/ERC20.sol";
import "./IExposureOracle.sol";
import "../../Util/Manageable.sol";
import "./IExposureManager.sol";
import "../../Util/Math.sol";

/**
  *  @title Exposure Asset
  *  @author Exposure
  *  @notice Manages a single token for an ExposureBasket
  *   - Manager:
  *    # Adds vesting contracts for a token to ignore from the supply
  *   - Owner:
  *    # Authorizes transfers
  *    # Authorizes trades
  *  @dev Ownable `owner()` is an ExposureManager contract.
  *  @dev Manageable `manager()` is the XPSR DAO.
  *  @dev ExposureAsset contracts are deployed through ExposureBasket.
*/
contract ExposureAsset is Ownable, Manageable {

    /**
      * @dev The ERC20 token address of the token this contract represents.
    */
    address public token;

    /**
      * @dev The USDC token address.
    */
    address public usdc;

    /**
      * @dev Trading pairs for buying and selling `token`.
    */
    address public tokenPairs;

    /**
      * @dev Constructor.
      * @param _usdc The token address of USDC.
      * @param _token The token address of the token this contract will manage.
      * @param _manager The manager address who has authorization to add addresses to `ignoredSupplyContracts`
    **/
    constructor(address _usdc, address _token, address _manager) {
        usdc = _usdc;
        token = _token;
        transferManagement(_manager);
    }

    /**
     * @notice Transfers tokens out of this contract.
     *
     * @param _recipient The account that will receive tokens.
     * @param amount The amount of tokens to transfer
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function authorizedTransfer(address _recipient, uint256 amount) external onlyOwner {
        IERC20(token).transfer(_recipient, amount);
    }

    /**
     * @return The market cap of `token`.
     */
    function getMarketCap() external view returns (uint256){
        return IExposureOracle(IExposureManager(owner()).oracle()).marketCap(token);
    }

    /**
     * @notice Gets the price of `token` from the price oracle.
     * @dev Updates the price oracle by calling `IExposureOracle.update(pairAddress)`.
     * @return The average price for `token`.
     */
    function getPrice() public view returns (uint256) {
        return IExposureOracle(IExposureManager(owner()).oracle()).price(token);
    }
}
