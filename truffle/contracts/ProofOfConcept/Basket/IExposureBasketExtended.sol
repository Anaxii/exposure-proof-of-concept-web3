// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;
import "./IExposureBasket.sol";

/**
  *  @title Exposure Basket Extended Interface
  *  @author Exposure
  *  @notice Main point of interaction for an individual Exposure Market Basket
  *   - Users can:
  *    # Mint basket tokens/shares in exchange for underlying assets
  *    # Redeem basket tokens/shares in exchange for underlying assets
  *    # Buy underlying assets in exchange for USDC during rebalances
  *    # Sell underlying assets in exchange for USDC during rebalances
  *    # Call rebalance steps
  *  @dev All admin functions are callable by the DAO and limited by Ownable
  *  @dev Exposure basket shares are represented as ERC20 tokens
*/
interface IExposureBasketExtended is IExposureBasket {
    /**
    * @notice The function that must be called to begin initializing the basket.
    * @dev Sets `rebalanceStep` to 1.
    *
    * Requirements:
    *
    * - `isLive` must be false (the basket has not been initialized).
    * - `rebalanceStep` must be 0.
    * - `onlyOwner`.
    */
    function startETF() external;

    /**
     * @notice The final step before initializing the basket.
     * @dev sets `isLive` to true.
     *
     * Requirements:
     *
     * - `isLive` must be false (the basket has not been initialized).
     * - `rebalanceStep` must be 10.
     * - `onlyOwner`.
     */
    function initETF() external;

    /**
     * @notice Sets the tokens for the next rebalance.
     * @dev Can only be called before a rebalance or during `rebalanceStep` 1. The only time
     * `rebalanceStep` is equal to 1 is when the basket is initializing.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function addTokens(
        address[] memory _tokens,
        address[][] memory _tokenPairs,
        address[][] memory pairTypes,
        address[][] memory oracles,
        address[][] memory routers
    ) external;

    /**
     * @notice Adds a token to the basket at the next rebalance.
     * @dev Can only be called before a rebalance or during `rebalanceStep` 1. The only time
     * `rebalanceStep` is equal to 1 is when the basket is initializing. If the `hasBeenAdded[_token][_epoch]
     * is true, it will return to prevent duplicate tokens in the basket.
     *
     * @dev if a token has been set to be removed from the basket but was is an argument in addToken, it
     * remove it from the queue to be removed.
     *
     * @dev Creates a new ExposureAsset contract through the `exposureAssetManager` contract.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     * - `rebalanceStep` must be 1 or 0.
     */
    function addToken(
        address _token,
        address[] memory
        _tokenPairs,
        address[] memory pairTypes,
        address[] memory oracles,
        address[] memory routers
    ) external;

    /**
     * @notice Removes an array of token from the basket during the next rebalance.
     * @dev Can be undone by calling `addToken`.
     *
     * @dev If the token had a fixed weight in the basket, that weight gets set to 0.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     * - `rebalanceStep` must 0.
     */
    function removeTokens(address[] memory _tokens) external;

    /**
    * @notice `owner()` can sell off a percentage of `tokenSellAmount[epoch][_token]` through the
    * ExposureAssetManager contract.
    * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
    *
    * @param percentage The percentage of tokenSellAmount[epoch][_token], the ExposureAssetManager should sell.
    * @param _token The token address of the token the caller wants to buy.
    *
    * @dev If `tokenSellAmount[epoch][_token]` is < 1000 the basket will skip the trade
    * due to the size being too small.
    * Requirements:
    *
    * - `rebalanceStep` must be 7.
    * - The caller must be the owner.
    */
    function rebaseLiquidateIndividual(uint256 percentage, address _token) external;

    /**
     * @notice `owner()` can buy a percentage of the tokens it needs based off its weight and the
     * total USDC received during `rebaseLiquidate`, `rebaseLiquidateIndividual`, and `buyFromExposure`.
     * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
     *
     * @param percentage The percentage of calculated buy amount the ExposureAssetManager should buy.
     * @param _token The token address of the token the caller wants to buy.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 8.
     * - The caller must be the owner.
     */
    function rebaseBuyIndividual(uint256 percentage, address _token) external;

    /**
     * @notice `owner()` can sell off a the remaining percentage of each `tokenSellAmount[epoch][_token]`
     * through the ExposureAssetManager contract.
     * @dev The basket will never buy tokens before it has already sold all of the tokens
     * in `tokenSellAmount[epoch][_token]` unless a token has bypassTrade[epoch][tokens[epoch][i]] set to true.
     *
     * @dev If `tokenSellAmount[epoch][_token]` is < 1000 the basket will skip the trade
     * due to the size being too small.
     * Requirements:
     *
     * - `rebalanceStep` must be 7.
     * - The caller must be the owner.
     */
    function rebaseLiquidate() external;

    /**
     * @notice `owner()` can buy  the remaining percentage of each token with
     * the remaining USDC balance in the ExposureAssetManager.
     *
     * @dev If `tokenBuyAmount[epoch][tokens[epoch][i]]` is < 1000 the basket will skip the trade
     * due to the size being too small.
     * Requirements:
     *
     * - `rebalanceStep` must be 8.
     * - The caller must be the owner.
     */
    function rebaseBuy() external;

    /**
    * @notice Sets the fixed weight of a basket token.
    * @dev if `_weight` is 0 then the weight will be based on market cap.
    *
    * @dev percentage is based on 1e18.
    * Requirements:
    *
    * - Caller must be the owner.
    * - The total fixed weight must be less than 1e18.
    * - The number of fixed weight tokens must be less than the total number of tokens.
    */
    function setFixedTokenWeight(address _token, uint256 _weight) external;

    /**
    * @notice Sets `XPSRAddress`.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setXPSRAddress(address _token) external;

    /**
    * @notice Sets `canBeDirectlyTraded` for a token.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setToBeDirectlyTraded(address _token, bool _value) external;

    /**
    * @notice Sets `rebalanceTimer`.
    * @dev This is the minimum time between rebalances.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setRebalanceTimer(uint256 _hours) external;

    /**
    * @notice Sets the fee for a user group.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setFeeTier(uint256 tier, uint256 _fee) external;

    /**
    * @notice Sets a users fee tier.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setUserFeeTier(uint256 tier, address _user) external;

    /**
    * @notice Sets the max supply of basket shares.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setBasketCap(uint256 _cap) external;

    /**
    * @notice Sets `maxSlippage`.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setMaxSlippage(uint256 _slippageFactor) external;

    /**
    * @notice Sets `expenseRatio`.
    * Requirements:
    *
    * - Caller must be the owner.
    * - The expense ratio must be under 500 (5%).
    */
    function changeExpenseRatio(uint256 _expenseRatio) external;

    /**
    * @notice Sets `XPSRRequirement` for minting and redeeming basket shares.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setXPSRRequirement(uint256 _req) external;

    /**
    * @notice Sets `buyAndSellFromFee` for trading directly with the basket during rebalances.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setBuyAndSellFromFee(uint256 _fee) external;

    /**
    * @notice Allows the basket to skip a token trade during a rebalance.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function addBypassTrade(address _token) external;
}
