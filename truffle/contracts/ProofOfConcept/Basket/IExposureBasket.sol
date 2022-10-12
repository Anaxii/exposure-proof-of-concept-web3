// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;
import "../../Util/IERC20.sol";

/**
  *  @title Exposure Basket Core Interface
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
interface IExposureBasket is IERC20 {
    /**
     * @dev rebalanceTimeStamp stores the next time a rebalance can occur.
     */
    function rebalanceTimeStamp(uint256 _epoch) external view returns (uint256);
    /**
     * @dev tokenFixedWeight is an optional set percentage of the total basket a token
     * should represent. eg 2e17 = 20% of the basket.
     */
    function tokenFixedWeight(address _token) external view returns (uint256);

    /**
     * @dev buyAndSellFromFee is the fee charged to users for trading tokens
     * directly with the basket during rebalances.
     */
    function buyAndSellFromFee() external view returns (uint256);

    /**
     * @dev epoch is the number of rebalances that have occurred
     */
    function epoch() external view returns (uint256);

    /**
     * @dev basketCap is the max number of basket shares that can be minted
     */
    function basketCap() external view returns (uint256);
    /**
     * @dev rebalanceStep is the current step during a rebalance. If 0 the basket
     * is not currently rebalancing.
     */
    function rebalanceStep() external view returns (uint256);

    /**
     * @dev The exposureManager is the middleman that talks to contracts holding
     * underlying assets and tells it to buy, sell, or transfer.
     */
    function exposureManager() external view returns (address);

    /**
     * @dev XPSRAddress is the XPSR governance token contract address.
     */
    function XPSRAddress() external view returns (address);

    /**
     * @notice Mints basket tokens in exchange for underlying asset. Fees are deducted via
     * basket shares. The amount is determined by `feeTiers` and `userFeeTier`.
     *
     * @param amount The number of basket tokens to mint.
     * @param to The receiver of the minted tokens.
     *
     * @dev Emits a {Transfer} event for each token.
     * @dev Emits a {BasketShareExchange} event.
     *
     * Requirements:
     *
     * - `isLive` must be true (the basket has been initialized).
     * - `rebalanceStep` must be 0 or 6.
     * - `from` must have a balance of at least `amount`.
     * - `totalSupply()` must be less than or equal to `basketCap` after minting new shares.
     * - User must approve XPSR Tokens (`XPSRAddress`) for the `XPSRRequirement`.
     */
    function mint(uint256 amount, address to) external;

    /**
     * @notice Redeems basket tokens in exchange for underlying asset. Fees are deducted via
     * basket shares. The amount is determined by `feeTiers` and `userFeeTier`.
     *
     * @param amount The number of basket tokens to mint.
     * @param to The receiver of the minted tokens.
     *
     * @dev Emits a {Transfer} event for each token.
     * @dev Emits a {BasketShareExchange} event.
     *
     * @dev if the basket gets stuck in a rebalance owners of basket shares can redeem their tokens
     * based on the previous portions of each token as a failsafe
     *
     * Requirements:
     *
     * - `isLive` must be true (the basket has been initialized).
     * - `rebalanceStep` must be 0 or 7 or `basketCap` must be set to 0.
     * - `from` must have a balance of at least `amount`.
     * - `totalSupply()` must be less than or equal to `basketCap` after minting new shares.
     * - User must approve XPSR Tokens (`XPSRAddress`) for the `XPSRRequirement`.
     */
    function burn(uint256 amount, address to) external;

    /**
     * @notice Begins the next rebalance.
     * @dev `rebalanceTimeStamp[epoch]` is the minimum timestamp before the next rebalance can happen.
     * `rebalanceTimer` determines the time increment for `rebalanceTimeStamp[epoch]. If the basket is
     * initializing, the increment will start from the current block timestamp, otherwise it will start from
     * `rebalanceTimeStamp[epoch].
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 0.
     * - `block.timestamp` must be greater than `rebalanceTimeStamp` set during the last rebalance.
     */
    function startRebalance() external;

    /**
     * @notice Sets the marketcap and price of each token in the basket for calculating weights
     * @dev if addTokens wasn't called prior to the current rebalance, all of the previous
     * tokens are copied over to the next epoch.
     *
     * Requirements:
     *
     * - `rebalanceStep` must 3.
     */
    function updateTokenMarketCap() external;

    /**
     * @notice Calculates the total weight of the basket based on the token market caps. Also
     * considers any fixed weight tokens.
     * Requirements:
     *
     * - `rebalanceStep` must be 4.
     */
    function updateWeightIndexTotal() external;

    /**
     * @notice Calculates the number of tokens the basket should hold for each token in `tokens`.
     * @dev values are stored in `tokenPortions`.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 5.
     */
    function updateTokenPortions() external;

    /**
     * @notice Extension of `updateTokenPortions`.
     * @dev If `rebalanceStep` is 0 there are now shares and `isLive` is false.
     * The basket will skip the next 2 steps which trade underlying assets in the basket.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 6.
     */
    function updateRemainingPortions() external;

    /**
     * @notice Allows users to buy tokens from the basket at the price that was
     * stored in `updateTokenMarketCap()`. Users are free to arbitrage the price difference between an exchange
     * and the basket while also paying a low 0.1% fee to transact with the basket. The user must approve USDC.
     * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
     *
     * @param amount The number of tokens to buy.
     * @param _token The token address of the token the caller wants to buy.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 7.
     * - `canBeDirectlyTraded[_token]` must be set to true.
     */
    function buyFromExposure(uint256 amount, address _token) external;

    /**
     * @notice Allows users to sell tokens to the basket at the price that was
     * stored in `updateTokenMarketCap()`. Users are free to arbitrage the price difference between an exchange
     * and the basket while also paying a low 0.1% fee to transact with the basket. The user will receive USDC.
     * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
     *
     * @param amount The number of tokens to buy.
     * @param _token The token address of the token the caller wants to buy.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 7.
     * - `canBeDirectlyTraded[_token]` must be set to true.
     */
    function sellToExposure(uint256 amount, address _token) external;



    /**
        * @notice Allows users to increment `rebalanceStep` if 99.9% of tokenSellAmount[epoch] was traded
        * for all required tokens.
        *
        * Requirements:
        *
        * - `rebalanceStep` must be 7.
        */
    function finishLiquidate() external;

    /**
     * @notice Allows users to increment `rebalanceStep` if the USDC balance is less than 10.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 8.
     */
    function finishBuy() external;

    /**
     * @notice Sets the index price of the new epoch.
     * @dev resets tokensToRemove
     *
     * @dev sets `tokens` for the new epoch.
     * Requirements:
     *
     * - `rebalanceStep` must be 9.
     */
    function finalizeIndexPrice() external;

    /**
     * @notice The final step for a new epoch.
     * @dev sets `rebalanceStep` back to 0.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 10.
     */
    function newEpoch() external;

    /**
     * @return (index[_epoch] * 1e18) / indexDivisor.
     */
    function getIndexPrice(uint256 _epoch) external view returns (uint256);

    /**
     * @return `calculateNAV(epoch)`.
     */
    function getNAVIndex(uint256 _epoch) external view returns (uint256);

    /**
      * @dev tokenMarketCaps stores each tokens market cap for determining its weight.
    */
    function getTokenMarketCap(uint256 _epoch, address _token) external view returns (uint256);

    /**
     * @dev tokenPortions is the amount of tokens one basket share represents.
     */
    function getTokenPortions(uint256 _epoch, address _token) external view returns (uint256);

    /**
     * @dev tokenPrices stores the token price to determine the amount
     * of tokens to buy and sell during a rebalance..
     */
    function getTokenPrice(uint256 _epoch, address _token) external view returns (uint256);

    /**
     * @dev tokenBuyAmount is the target amount of tokens to buy during a rebalance.
     */
    function getTokenBuyAmount(uint256 _epoch, address _token) external view returns (uint256);

    /**
     * @dev tokenSellAmount is the number of tokens the basket will sell for USDC during a rebalance.
     */
    function getTokenSellAmount(uint256 _epoch, address _token) external view returns (uint256);

    /**
      * @dev tokens is a list of all the tokens in the basket.
    */
    function getTokens(uint256 _epoch, uint256 _index) external view returns (address);
}
