// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../../../Util/IUniswapV2Pair.sol';
import "../../../Util/IERC20Metadata.sol";

contract ExposureMainnetOracle {

    mapping(address => uint256) public price;
    mapping(address => uint256) public liquidity;

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
            reserve0 = reserve0 * (10**(18-_decimal0));
        }
        if (_decimal1 != 18) {
            reserve1 = reserve1 * (10**(18-_decimal1));
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
}
