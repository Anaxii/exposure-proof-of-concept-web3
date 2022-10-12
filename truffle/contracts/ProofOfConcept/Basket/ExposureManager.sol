// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "../../Util/Ownable.sol";
import "../../Util/Strings.sol";
import "../../Util/Context.sol";
import "../../Util/IERC20.sol";
import "./IExposureAsset.sol";
import "../../Util/Manageable.sol";
import "./ExposureAsset.sol";

/**
  *  @title Exposure Manager
  *  @author Exposure
  *  @notice Middleman for communication between ExposureBasket and ExposureAsset contracts
  *   - ExposureBasket:
  *    # Deploy new ExposureAsset contracts
  *    # Authorize buying, selling, or transferring tokens in an ExposureAsset contract
  *    # Adjust the percentage of tokens that was traded for an epoch
  *   - Manager:
  *    # Set token pairs.
  *    # Set on-chain price oracles.
  *   - Users:
  *    # Get ExposureAssets contracts addresses for a token
  *    # Read balances, prices, and market caps of a token
  *  @dev Ownable `owner()` is an ExposureBasket contract.
  *  @dev Manageable `manager()` is the XPSR DAO.
  *  @dev ExposureAsset contracts are deployed through this contract.
*/
contract ExposureManager is Ownable, Manageable {

    /**
      * @dev Tracking the percentage of USDC allocated towards buying a token.
    */
    mapping(uint256 => mapping(address => uint256)) public amountBought;

    /**
      * @dev Tracking the percentage of tokens sold for a particular epoch.
    */
    mapping(uint256 => mapping(address => uint256)) public amountSold;

    /**
      * @dev An array of all authorized token pairs for a token.
    */
    mapping(address => address[]) public tokenPairs;

    /**
      * @dev The quote token of a token pair.
    */
    mapping(address => address) public pairType;

    /**
      * @dev The ExposureAsset contract address for a token.
    */
    mapping(address => address) public exposureAssetAddresses;

    /**
      * @dev ExposureOracle address of a DEX router address.
    */
    address public oracle;

    /**
      * @dev The router for a `tokenPairs[_token]`.
    */
    mapping(address => address) public tradingRouters;

    /**
      * @dev A mapping of authorized accounts for `authorizedTransfer`.
    */
    mapping(address => bool) public authorizedTransferee;

    /**
     * @dev USDC ERC20 token address.
    */
    address public usdc;

    /**
      * @dev Constructor.
      * @param _usdc The token address of USDC
      * @param _oracle The oracles to be used for each item in `_routers`
    **/
    constructor(address _usdc, address _oracle) {
        authorizedTransferee[msg.sender] = true;
        usdc = _usdc;
        oracle = _oracle;
    }

    /**
     * @notice Sets up a token for use in an ExposureBasket contract.
     *
     * @param _token The token address of the token being added.
     * @param _pairs An array of tokens pairs authorized for trading.
     * @param _quotes A array of quote address for each pair in `_pairs`.
     * @param _oracles Array of ExposureOracle address for getting price/mcap.
     * @param _routers An array routers for each element in `_oracles`.
     *
     * Requirements:
     *
     * - All arrays must be the same length.
     */
    function batchNewAssetManager(
        address _token,
        address[] memory _pairs,
        address[] memory _quotes,
        address[] memory _oracles,
        address[] memory _routers
    ) external onlyOwner {
        require(
            _pairs.length == _quotes.length &&
            _quotes.length == _oracles.length &&
            _oracles.length == _routers.length,
            "invalid lengths"
        );
        newAssetManager(_token);
        setPairs(_token, _pairs);
        for (uint i = 0; i < _pairs.length; i++) {
            setPairTypes(_pairs[i], _quotes[i]);
            setOracle(_oracles[i], _routers[i]);
            setRouter(_routers[i], _pairs[i]);
        }
    }

    /**
     * @notice Sets the available trading pairs for ExposureAssets contracts.
     *
     * @param _token The token address of the token being added.
     * @param _pairs An array of tokens pairs authorized for trading.
     *
     * Requirements:
     *
     * - Caller must be the owner or manager.
     */
    function setPairs(address _token, address[] memory _pairs) public {
        require(msg.sender == owner() || msg.sender == manager());
        tokenPairs[_token] = _pairs;
        IExposureAsset(exposureAssetAddresses[_token]).setPairs(_pairs);
    }

    /**
     * @notice Sets the router for a trading pair.
     *
     * @param router The contract address of a DEX router.
     * @param tokenPair The DEX pair `router` is set to.
     *
     * Requirements:
     *
     * - Caller must be the owner or manager.
     */
    function setRouter(address router, address tokenPair) public {
        require(msg.sender == owner() || msg.sender == manager());
        tradingRouters[tokenPair] = router;
    }

    /**
     * @notice Sets the quote token of trading pair for reading in ExposureAsset contracts.
     *
     * @param tokenPair The DEX pair `router` is set to.
     * @param quoteToken The quote token of a trading pair.
     *
     * Requirements:
     *
     * - Caller must be the owner or manager.
     */
    function setPairTypes(address tokenPair, address quoteToken) public {
        require(msg.sender == owner() || msg.sender == manager());
        pairType[tokenPair] = quoteToken;
    }

    /**
     * @notice Sets the price oracle for getting price data for a router address.
     *
     * @param _oracle The price oracle for getting prices/mcaps.
     * @param _router The router used by `_oracle`.
     *
     * Requirements:
     *
     * - Caller must be the owner or manager.
     */
    function setOracle(address _oracle, address _router) public {
        require(msg.sender == owner() || msg.sender == manager());
        oracle = _oracle;
    }

    /**
     * @notice Deploys a new ExposureAsset contract for a token.
     *
     * @param _token The token that will be associated with the new ExposureAsset contract.
     * @dev The contract address can be read in `exposureAssetAddresses[underlyingAssetAddress]`.
     *
     * Requirements:
     *
     * - Caller must be the owner or manager.
     */
    function newAssetManager(address _token) public {
        require(msg.sender == owner() || msg.sender == manager());
        if (exposureAssetAddresses[_token] != address(0))
            return;
        ExposureAsset e = new ExposureAsset(usdc, _token, manager());
        exposureAssetAddresses[_token] = address(e);
    }

    /**
     * @notice Transfers tokens out of an ExposureAsset contract.
     *
     * @param _token The token that will to be transferred.
     * @param _recipient Receiver of the tokens transferred.
     * @param amount Number of tokens being transfered
     * @dev The contract address can be read in `exposureAssetAddresses[underlyingAssetAddress]`.
     *
     * Requirements:
     *
     * - `authorizedTransferee[_msgSender()]` must be true.
     */
    function authorizedTransfer(address _token, address _recipient, uint256 amount) external {
        require(authorizedTransferee[_msgSender()]);
        IExposureAsset(exposureAssetAddresses[_token]).authorizedTransfer(_recipient, amount);
    }

    /**
     * @notice Manually increases the percentage of tokens traded.
     * @dev This is used in `buyFromExposure` and `sellToExposure` in ExposureBasket contracts.
     *
     * @param buyOrSell Determines which variable to adjust.
     * @param epoch The ExposureBasket contract's current epoch.
     * @param _token The token that was traded.
     * @param amount The amount to increment the `amountBought[epoch][_token]` or `amountSold[epoch][_token]`.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function increaseAmountTraded(
        uint256 buyOrSell,
        uint256 epoch,
        address _token,
        uint256 amount
    ) external onlyOwner {
        if (buyOrSell == 0) {
            amountBought[epoch][_token] += amount;
        }
        if (buyOrSell == 1) {
            amountSold[epoch][_token] += amount;
        }
    }

    /**
     * @notice Withdraws USDC from this contract for `sellToExposure` in ExposureBasket.
     *
     * @param amount The amount of USDC to transfer.
     * @param recipient The receiver of the USDC.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function getUSDC(uint256 amount, address recipient) external onlyOwner {
        IERC20(usdc).transfer(recipient, amount);
    }

    /**
     * @notice Get the balance of a token in an ExposureAsset contract.
     *
     * @param _token The contract address of an ERC20 token.
     * @return Balance of `_token` in an ExposureAsset contract.
     */
    function getBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(exposureAssetAddresses[_token]);
    }

    /**
     * @notice Gets the price of a token determined by an ExposureAsset contract.
     *
     * @param _token The contract address of an ERC20 token.
     * @return The price of `_token`.
     */
    function getPrice(address _token) external view returns (uint256) {
        return IExposureAsset(exposureAssetAddresses[_token]).getPriceNoUpdate();
    }

    /**
     * @notice Gets the mcap of a token determined by an ExposureAsset contract.
     *
     * @param _token The contract address of an ERC20 token.
     * @return The mcap of `_token`.
     */
    function getMarketCap(address _token) external view returns (uint256) {
        return IExposureAsset(exposureAssetAddresses[_token]).getMarketCap();
    }

    /**
     * @notice Gets a token pair address for a token with an ExposureAsset contract.
     *
     * @param _token The token.
     * @param _index The index of the array to read.
     * @return A DEX pair contract address.
     */
    function getTokenPair(address _token, uint256 _index) external view returns (address) {
        return tokenPairs[_token][_index];
    }

    /**
     * @notice Authorizes a sell in an ExposureAsset contract.
     *
     * @param _token The token to trade.
     * @param percentage The percentage of `swapAmount` to trade (percentage/1e18).
     * @param swapAmount The amount of tokens to sell.
     * @param maxSlippage The max allowed slippage when trading tokens.
     * @param epoch The current ExposureBasket epoch.
     *
     * @dev if the new percentage is over 1e18 then adjust the percentage.
     * @dev if the current percentage is already 1e18 then return.
     * @dev If the token to trade is USDC stop after transferring USDC out of the ExposureAsset contract.
     *
     * @return tokenBalance / totalSharesOfBasket.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function liquidate(
        address _token,
        uint256 percentage,
        uint256 swapAmount,
        uint256 maxSlippage,
        uint256 epoch
    ) external onlyOwner returns (uint256) {
        if (amountSold[epoch][_token] + percentage > 1e18) {
            if (amountSold[epoch][_token] >= 1e18) {
                return getNewPortion(_token);
            }
            percentage = 1e18 - amountSold[epoch][_token];
        }
        amountSold[epoch][_token] += percentage;
        if (_token == usdc) {
            if (swapAmount * percentage / 1e18 > getBalance(_token)) {
                swapAmount = getBalance(_token);
            }
            IExposureAsset(exposureAssetAddresses[_token]).authorizedTransfer(
                address(this),
                swapAmount * percentage / 1e18
            );
            return getNewPortion(_token);
        }

        swapAmount = swapAmount * percentage / 1e18;
        if (swapAmount > getBalance(_token)) {
            swapAmount = getBalance(_token);
        }
        IExposureAsset(exposureAssetAddresses[_token]).routeLiquidate(swapAmount, maxSlippage);
        return getNewPortion(_token);
    }

    /**
     * @notice Authorizes a buy in an ExposureAsset contract.
     *
     * @param _token The token to trade.
     * @param percentage The percentage of `usdToBuy` to trade (percentage/1e18).
     * @param tokenWeight The tokens basket weight.
     * @param totalWeight The total weight of tokens being traded.
     * @param usdToBuy The amount of USDC left after all calls to `liquidate()`.
     * @param maxSlippage The max allowed slippage when trading tokens.
     * @param epoch The current ExposureBasket epoch.
     *
     * @dev If the new percentage is over 1e18 then adjust the percentage.
     * @dev If the current percentage is already 1e18 then return.
     * @dev `buyingPercentage` adjust the weight of the tokens to relative to `totalWeight` instead of
     * the ExposureBasket contracts total weight.
     * @dev If the amount of USDC is greater than the balance, adjust the amount for buying to the balance.
     * @dev If the token to trade is USDC stop after transferring USDC to the ExposureAsset contract.
     *
     * @return tokenBalance / totalSharesOfBasket.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function purchase(
        address _token,
        uint256 percentage,
        uint256 tokenWeight,
        uint256 totalWeight,
        uint256 usdToBuy,
        uint256 maxSlippage,
        uint256 epoch
    ) external onlyOwner returns (uint256) {
        if (amountBought[epoch][_token] + percentage > 1e18) {
            if (amountBought[epoch][_token] >= 1e18) {
                return getNewPortion(_token);
            }
            percentage = 1e18 - amountBought[epoch][_token];
        }
        amountBought[epoch][_token] += percentage;

        uint256 buyingPercentage = ((((tokenWeight * (1e18)) / totalWeight) * (1e18 - totalWeight)) / 1e18) + tokenWeight;

        usdToBuy = usdToBuy * percentage / 1e18;
        usdToBuy = ((usdToBuy * buyingPercentage) / 1e18);

        if (IERC20(usdc).balanceOf(address(this)) == 0) {
            return getNewPortion(_token);
        }


        if (IERC20(usdc).balanceOf(address(this)) < usdToBuy) {
            usdToBuy = IERC20(usdc).balanceOf(address(this));
        }

        IERC20(usdc).transfer(exposureAssetAddresses[_token], usdToBuy);

        if (_token == usdc) {
            return getNewPortion(_token);
        }

        IExposureAsset(exposureAssetAddresses[_token]).routeBuying(usdToBuy, maxSlippage);
        return getNewPortion(_token);
    }

    /**
     * @notice Calculates the new portion for ExposureBasket contracts.
     *
     * @param _token The contract address of an ERC20 token.
     */
    function getNewPortion(address _token) internal view returns (uint256) {
        return getBalance(_token) * 1e18 / IERC20(owner()).totalSupply();
    }

    /**
     * @return The percentage of tokens traded in `purchase` for a particular token.
     */
    function getAmountBought(address _token, uint256 _epoch) external view returns (uint256) {
        return amountBought[_epoch][_token];
    }

    /**
     * @return The percentage of tokens traded in `liquidate` for a particular token.
     */
    function getAmountSold(address _token, uint256 _epoch) external view returns (uint256) {
        return amountSold[_epoch][_token];
    }

    /**
     * @notice Allows an account to authorize transfers out of ExposureAsset contracts.
     *
     * @param _account The account to allow/deny authorization.
     * @param _value true authorizes account false removes authorization from an account.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function setAuthorizedTransferee(address _account, bool _value) external onlyManager {
        authorizedTransferee[_account] = _value;
    }
}

