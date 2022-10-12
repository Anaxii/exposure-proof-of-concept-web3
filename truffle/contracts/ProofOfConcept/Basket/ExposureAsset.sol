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
      * @dev Contracts holding tokens that don't get counted towards the circulating supply.
    */
    address[] public ignoredSupplyContracts;

    /**
      * @dev If address is true the `ignoredSupplyContracts[_address]` will be skipped.
    */
    mapping(address => bool) public noLongerIgnored;

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
    address[] public tokenPairs;

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
     * @notice Sets the available trading pairs for `token`.
     *
     * @param _pairs An array of tokens pairs authorized for trading `token`.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function setPairs(address[] memory _pairs) external onlyOwner {
        tokenPairs = _pairs;
    }

    /**
     * @notice Sets `ignoredSupplyContracts`.
     *
     * @param _contract The contract to ignore.
     *
     * Requirements:
     *
     * - Caller must be the manager.
     */
    function addIgnoredContract(address _contract) external onlyManager {
        ignoredSupplyContracts.push(_contract);
    }

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
    function removeIgnoredContract(address _contract, bool _value) external onlyManager {
        noLongerIgnored[_contract] = _value;
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
     * @notice Calculates the total supply of `token`.
     * @dev Deducts account balances for any tokens held under address in `ignoredSupplyContracts`.
     */
    function getCirculatingTokenSupply() public view returns (uint256) {
        uint256 token_supply = IERC20(token).totalSupply();

        for (uint256 i = 0; i < ignoredSupplyContracts.length; i++) {
            if (!noLongerIgnored[ignoredSupplyContracts[i]])
                token_supply -= IERC20(token).balanceOf(ignoredSupplyContracts[i]);
        }
        return token_supply;
    }

    /**
     * @return The market cap of `token`.
     */
    function getMarketCap() external view returns (uint256){
        return (getPriceNoUpdate() * (getCirculatingTokenSupply())) / 1e18;
    }

    /**
     * @return The number of `token` for each address in `tokenPair` and the sum of all those tokens.
     */
    function getLiquidities() public view returns (uint256[] memory, uint256) {
        uint256[] memory liquidity = new uint256[](tokenPairs.length);
        uint256 liquiditySum = 0;

        for (uint256 i = 0; i < tokenPairs.length; i++) {
            address tokenpair = tokenPairs[i];

            (uint p0, uint p1,) = IPair(tokenpair).getReserves();
            address token0 = IPair(tokenpair).token0();
            if (token == token0) {
                liquiditySum += p0;
                liquidity[i] = p0;
            } else {
                liquiditySum += p1;
                liquidity[i] = p1;
            }
        }

        return (liquidity, liquiditySum);
    }

    /**
     * @notice Gets the price of `token` from the price oracle.
     * @dev Updates the price oracle by calling `IExposureOracle.update(pairAddress)`.
     * @return The average price for `token`.
     */
    function getPrice() public returns (uint256) {
        uint256 priceSum = 0;

        for (uint256 i = 0; i < tokenPairs.length; i++) {
            address tokenpair = tokenPairs[i];
            address quote = IExposureManager(owner()).pairType(tokenpair);

            IExposureOracle(IExposureManager(owner()).oracles(IExposureManager(owner()).tradingRouters(tokenpair))).update(quote, token);
            uint256 price = IExposureOracle(IExposureManager(owner()).oracles(IExposureManager(owner()).tradingRouters(tokenpair))).consult(quote, token);
            if (quote != usdc) {
                IExposureOracle(IExposureManager(owner()).oracles(IExposureManager(owner()).tradingRouters(tokenpair))).update(usdc, quote);
                uint256 usdcQuotePrice = IExposureOracle((IExposureManager(owner()).oracles(IExposureManager(owner()).tradingRouters(tokenpair)))).consult(usdc, quote);
                price = price * usdcQuotePrice / 1e18;
            }
            priceSum += price;
        }

        return priceSum / tokenPairs.length;
    }

    /**
     * @notice Gets the price of `token` from the price oracle.
     * @dev Does not call `IExposureOracle.update(pairAddress)` for `token`
     * allowing this function to be a view.
     * @return The average price for `token`.
     */
    function getPriceNoUpdate() public view returns (uint256) {
        uint256 priceSum = 0;

        for (uint256 i = 0; i < tokenPairs.length; i++) {
            address tokenpair = tokenPairs[i];
            address quote = IExposureManager(owner()).pairType(tokenpair);

            uint256 price = IExposureOracle(IExposureManager(owner()).oracles(IExposureManager(owner()).tradingRouters(tokenpair))).consult(quote, token);
            if (quote != usdc) {
                uint256 usdcQuotePrice = IExposureOracle((IExposureManager(owner()).oracles(IExposureManager(owner()).tradingRouters(tokenpair)))).consult(usdc, quote);
                price = price * usdcQuotePrice / 1e18;
            }
            priceSum += price;
        }

        return priceSum / tokenPairs.length;
    }

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
    function routeLiquidate(uint256 amount, uint256 slippageFactor) external onlyOwner {

        (uint256[] memory lqs, uint256 liqSum) = getLiquidities();

        for (uint256 i = 0; i < tokenPairs.length; i++) {
            address tokenpair = tokenPairs[i];
            address router = IExposureManager(owner()).tradingRouters(tokenpair);
            uint256 weight = lqs[i] * 1e18 / liqSum;
            amount = amount * weight / 1e18;

            if ((i == tokenPairs.length - 1 && amount > IERC20(token).balanceOf(address(this)))) {
                if (IERC20(token).balanceOf(address(this)) == 0)
                    return;

                amount = IERC20(token).balanceOf(address(this));
            }

            address[] memory path = new address[](2);
            uint256[] memory amountOutMins = new uint256[](2);
            uint256 _out;
            address quote = IExposureManager(owner()).pairType(tokenPairs[i]);
            if (quote != usdc) {
                path[0] = token;
                path[1] = quote;
                amountOutMins = IUniswapV2Router01(router).getAmountsOut(amount, path);
                _out = amountOutMins[1];
                IERC20(token).approve(router, amount);
                IUniswapV2Router01(router).swapExactTokensForTokens(
                    amount,
                    _out - ((_out * slippageFactor) / 10000),
                    path,
                    address(this),
                    block.timestamp + 40 seconds
                );

                amount = IERC20(quote).balanceOf(address(this));
            } else {
                quote = token;
            }

            path[0] = quote;
            path[1] = usdc;
            amountOutMins = IUniswapV2Router01(router).getAmountsOut(amount, path);
            _out = amountOutMins[1];
            IERC20(quote).approve(router, amount);
            IUniswapV2Router01(router).swapExactTokensForTokens(
                amount,
                _out - ((_out * slippageFactor) / 10000),
                path,
                owner(),
                block.timestamp + 40 seconds);
        }
    }

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
    function routeBuying(uint256 amount, uint256 slippageFactor) external onlyOwner {
        (uint256[] memory lqs, uint256 liqSum) = getLiquidities();

        for (uint256 i = 0; i < tokenPairs.length; i++) {
            address tokenpair = tokenPairs[i];
            address quote = IExposureManager(owner()).pairType(tokenpair);
            address router = IExposureManager(owner()).tradingRouters(tokenpair);
            uint256 weight = lqs[i] * 1e18 / liqSum;
            amount = amount * weight / 1e18;

            if ((i == tokenPairs.length - 1 && amount > IERC20(usdc).balanceOf(address(this))))
                amount = IERC20(usdc).balanceOf(address(this));


            address[] memory path = new address[](2);
            uint256[] memory amountOutMins = new uint256[](2);
            uint256 _out;
            if (quote != usdc) {
                path[0] = usdc;
                path[1] = quote;
                amountOutMins = IUniswapV2Router01(router).getAmountsOut(amount, path);
                _out = amountOutMins[1];
                if (amount == 0 || _out == 0)
                    continue;

                require(IERC20(usdc).approve(router, amount));
                IUniswapV2Router01(router).swapExactTokensForTokens(
                    amount,
                    _out - ((_out * slippageFactor) / 10000),
                    path,
                    address(this),
                    block.timestamp + 40 seconds
                );

                amount = IERC20(quote).balanceOf(address(this));
            }

            path[0] = quote;
            path[1] = token;
            amountOutMins = IUniswapV2Router01(router).getAmountsOut(amount, path);
            _out = amountOutMins[1];
            if (amount == 0 || _out == 0)
                continue;

            IERC20(quote).approve(router, amount);
            IUniswapV2Router01(router).swapExactTokensForTokens(
                amount,
                _out - ((_out * slippageFactor) / 10000),
                path,
                address(this),
                block.timestamp + 40 seconds
            );

        }
    }

}
