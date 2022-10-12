// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

interface IExposureAsset {

    /**
      * @dev Contracts holding tokens that don't get counted towards the circulating supply.
    */
    function ignoredSupplyContracts(uint256 _index) external view returns (address);

    /**
      * @dev If address is true the `ignoredSupplyContracts[_address]` will be skipped.
    */
    function noLongerIgnored(address _token) external view returns (bool);

    /**
      * @dev The ERC20 token address of the token this contract represents.
    */
    function token() external view returns (address);

    /**
      * @dev The USDC token address.
    */
    function usdc() external view returns (address);

    /**
      * @dev Trading pairs for buying and selling `token`.
    */
    function tokenPairs(uint256 _index) external view returns (address);

    /**
     * @notice Sets the available trading pairs for `token`.
     *
     * @param _pairs An array of tokens pairs authorized for trading `token`.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function setPairs(address[] memory _pairs) external;

    /**
     * @notice Sets `ignoredSupplyContracts`.
     *
     * @param _contract The contract to ignore.
     *
     * Requirements:
     *
     * - Caller must be the manager.
     */
    function addIgnoredContract(address _contract) external;

    /**
     * @notice Sets `noLongerIgnored`.
     *
     * @param _contract The contract address to adjust.
     * @param _value `noLongerIgnored` can be true or false.
     *
     * Requirements:
     *
     * - Caller must be the manager.
     */
    function removeIgnoredContract(address _contract, bool _value) external;

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
    function authorizedTransfer(address _recipient, uint256 amount) external;

    /**
     * @notice Calculates the total supply of `token`.
     * @dev Deducts account balances for any tokens held under address in `ignoredSupplyContracts`.
     */
    function getCirculatingTokenSupply() external view returns (uint256);

    /**
     * @return The market cap of `token`.
     */
    function getMarketCap() external view returns (uint256);

    /**
     * @return The number of `token` for each address in `tokenPair` and the sum of all those tokens.
     */
    function getLiquidities() external view returns (uint256[] memory, uint256);

    /**
     * @notice Gets the price of `token` from the price oracle.
     * @dev Updates the price oracle by calling `IExposureOracle.update(pairAddress)`.
     * @return The average price for `token`.
     */
    function getPrice() external returns (uint256);

    /**
     * @notice Gets the price of `token` from the price oracle.
     * @dev Does not call `IExposureOracle.update(pairAddress)` for `token`
     * allowing this function to be a view.
     * @return The average price for `token`.
     */
    function getPriceNoUpdate() external view returns (uint256);

    /**
     * @notice Sells `token` to each DEX pair in `tokenPairs`.
     *
     * @param amount The number of `token` to sell.
     * @param slippageFactor The max slippage allowed while trading tokens.
     *
     * @dev Splits up sells between all `tokenPairs` based on each pair's liquidity.
     * @dev Multiple sells are authorized if the quote is not USDC.
     * @dev All USDC gets sent to the owner or the ExposureManager contract for
     * reallocation.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function routeLiquidate(uint256 amount, uint256 slippageFactor) external;

    /**
     * @notice Sells `token` to each DEX pair in `tokenPairs`.
     *
     * @param amount The number of `token` to sell.
     * @param slippageFactor The max slippage allowed while trading tokens.
     *
     * @dev Splits up buys between all `tokenPairs` based on each pair's liquidity.
     * @dev Multiple buys are authorized if the quote is not USDC.
     * @dev ExposureManager transfers the amount of USDC authorized for buying prior to calling `routeBuying`.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function routeBuying(uint256 amount, uint256 slippageFactor) external;
}
