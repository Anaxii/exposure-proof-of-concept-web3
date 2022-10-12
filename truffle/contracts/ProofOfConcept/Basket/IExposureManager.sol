// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

/**
  *  @title Exposure Manager Interface
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
interface IExposureManager {

    /**
      * @dev Tracking the percentage of USDC allocated towards buying a token.
    */
    function amountBought(uint256 _epoch, address _token) external view returns (uint256);

    /**
      * @dev Tracking the percentage of tokens sold for a particular epoch.
    */
    function amountSold(uint256 _epoch, address _token) external view returns (uint256);

    /**
      * @dev The quote token of a token pair.
    */
    function pairType(address _token) external view returns (address);

    /**
      * @dev The ExposureAsset contract address for a token.
    */
    function exposuireAssetAddresses(address _token) external view returns (address);

    /**
      * @dev ExposureOracle address of a DEX router address.
    */
    function oracles(address _router) external view returns (address);

    /**
      * @dev The router for a `tokenPairs[_token]`.
    */
    function tradingRouters(address _tokenPair) external view returns (address);

    /**
      * @dev A mapping of authorized accounts for `authorizedTransfer`.
    */
    function authorizedTransferee(address _account) external view returns (bool);

    /**
     * @dev USDC ERC20 token address.
    */
    function usdc() external view returns (address);

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
    ) external;

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
    function setPairs(address _token, address[] memory _pairs) external;

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
    function setRouter(address router, address tokenPair) external;

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
    function setPairTypes(address tokenPair, address quoteToken) external;

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
    function setOracle(address _oracle, address _router) external;

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
    function newAssetManager(address _token) external;

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
    function authorizedTransfer(address _token, address _recipient, uint256 amount) external;

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
    ) external;

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
    function getUSDC(uint256 amount, address recipient) external;

    /**
     * @notice Get the balance of a token in an ExposureAsset contract.
     *
     * @param _token The contract address of an ERC20 token.
     * @return Balance of `_token` in an ExposureAsset contract.
     */
    function getBalance(address _token) external view returns (uint256);

    /**
     * @notice Gets the price of a token determined by an ExposureAsset contract.
     *
     * @param _token The contract address of an ERC20 token.
     * @return The price of `_token`.
     */
    function getPrice(address _token) external view returns (uint256);

    /**
     * @notice Gets the mcap of a token determined by an ExposureAsset contract.
     *
     * @param _token The contract address of an ERC20 token.
     * @return The mcap of `_token`.
     */
    function getMarketCap(address _token) external view returns (uint256);

    /**
     * @notice Gets a token pair address for a token with an ExposureAsset contract.
     *
     * @param _token The token.
     * @param _index The index of the array to read.
     * @return A DEX pair contract address.
     */
    function getTokenPair(address _token, uint256 _index) external view returns (address);

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
    ) external returns (uint256);

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
    ) external returns (uint256);

    /**
     * @return The percentage of tokens traded in `purchase` for a particular token.
     */
    function getAmountBought(address _token, uint256 _epoch) external view returns (uint256);

    /**
     * @return The percentage of tokens traded in `liquidate` for a particular token.
     */
    function getAmountSold(address _token, uint256 _epoch) external view returns (uint256);

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
    function setAuthorizedTransferee(address _account, bool _value) external;
    function exposureAssetAddresses(address _address) external view returns (address);

}
