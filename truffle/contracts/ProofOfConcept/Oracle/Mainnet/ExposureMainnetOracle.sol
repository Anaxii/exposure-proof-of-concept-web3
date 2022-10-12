// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../../../Util/IUniswapV2Pair.sol';
import "../../../Util/IERC20Metadata.sol";
import "../../../Util/Ownable.sol";
import "../../../Uniswap/IUniswapV2Router01.sol";

contract ExposureMainnetOracle is Ownable {

    mapping(address => uint256) public price;
    mapping(address => uint256) public liquidity;

    /**
  * @dev Contracts holding tokens that don't get counted towards the circulating supply.
*/
    mapping(address => address[]) public ignoredSupplyContracts;

    /**
      * @dev If address is true the `ignoredSupplyContracts[_address]` will be skipped.
    */
    mapping(address => mapping(address => bool)) public noLongerIgnored;

    event UpdatedPrice(uint256 indexed price, address indexed token, address indexed quote, address pair);

    function updateMultiple(address[] memory pairs, address[] memory tokenIns, address[] memory tokenOuts) external {
        require(pairs.length == tokenIns.length && pairs.length == tokenOuts.length);

        for (uint256 i = 0; i < pairs.length; i++) {
            updatePrice(pairs[i], tokenIns[i], tokenOuts[i]);
        }
    }

    function updatePrice(address pair, address tokenIn, address tokenOut) public returns (uint updatedPrice) {
        require(IUniswapV2Pair(pair).token0() == tokenIn || IUniswapV2Pair(pair).token0() == tokenOut);
        require(IUniswapV2Pair(pair).token1() == tokenIn || IUniswapV2Pair(pair).token1() == tokenOut);

        (uint256 reserve0, uint256 reserve1, uint32 _timestamp) = IUniswapV2Pair(pair).getReserves();

        uint256 _decimal0 = IERC20Metadata(IUniswapV2Pair(pair).token0()).decimals();
        uint256 _decimal1 = IERC20Metadata(IUniswapV2Pair(pair).token1()).decimals();
        if (_decimal0 != 18) {
            reserve0 = reserve0 * (10 ** (18 - _decimal0));
        }
        if (_decimal1 != 18) {
            reserve1 = reserve1 * (10 ** (18 - _decimal1));
        }

        uint _price = 0;
        uint liq = 0;
        if (IUniswapV2Pair(pair).token0() == tokenIn) {
            _price = reserve0 * 1e18 / reserve1;
        } else {
            _price = reserve1 * 1e18 / reserve0;
        }

        price[pair] = _price;
        liquidity[pair] = IERC20(tokenIn).balanceOf(pair);
        emit UpdatedPrice(_price, tokenIn, tokenOut, pair);

        return _price;
    }

    function authorizedTrade(address router, address[] memory path, uint256 amountToSell, uint256 maxSlippage) external onlyOwner {
        uint256[] memory amountOutMins = IUniswapV2Router01(router).getAmountsOut(amountToSell, path);
        uint256 _out = amountOutMins[amountOutMins.length - 1];
        IUniswapV2Router01(router).swapExactTokensForTokens(
            amountToSell,
            _out - ((_out * maxSlippage) / 1e18),
            path,
            address(this),
            block.timestamp + 40 seconds
        );
    }

    /**
     * @notice Calculates the total supply of `token`.
     * @dev Deducts account balances for any tokens held under address in `ignoredSupplyContracts`.
     */
    function getCirculatingTokenSupply(address _token) public view returns (uint256) {
        uint256 token_supply = IERC20(_token).totalSupply();

        for (uint256 i = 0; i < ignoredSupplyContracts[_token].length; i++) {
            if (!noLongerIgnored[_token][ignoredSupplyContracts[_token][i]])
                token_supply -= IERC20(_token).balanceOf(ignoredSupplyContracts[_token][i]);
        }
        return token_supply;
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
    function addIgnoredContract(address _token, address _contract) external onlyOwner {
        ignoredSupplyContracts[_token].push(_contract);
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
    function updateIgnoredContract(address _contract, address _token, bool _value) external onlyOwner {
        noLongerIgnored[_token][_contract] = _value;
    }
}
