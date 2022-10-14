// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Util/Ownable.sol";
import "../Bridge/Mainnet/IExposureMainnetBridge.sol";
import "../../Util/IERC20.sol";
import "../../Uniswap/IUniswapV2Router01.sol";

contract ExposureBasketMainnetAssets is Ownable {
    address public bridge;

    event Swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event UpdateSubnet();

    constructor(address _bridge) {
        bridge = _bridge;
    }

    function transferOut(address _asset, uint256 _amount) external onlyOwner {
        IERC20(_asset).transfer(bridge, _amount);
    }

    function transferIn(address _asset, uint256 _amount) external onlyOwner {
        IExposureMainnetBridge(bridge).authorizedWithdraw(_asset, _amount);
    }

    function updateSubnet() external onlyOwner {
        emit UpdateSubnet();
    }

    function swapBridgedAsset(
        address[] memory path,
        uint256 amountIn,
        uint256 maxSlippage,
        address router
    )
    public
    onlyOwner
    returns (uint256) {
        require(maxSlippage < 1e18);
        uint256[] memory amountOutMins = IUniswapV2Router01(router).getAmountsOut(amountIn, path);
        uint256 out = amountOutMins[path.length - 1];
        IERC20(path[0]).approve(router, amountIn);
        uint256[] memory amounts = IUniswapV2Router01(router).swapExactTokensForTokens(
            amountIn,
            out - ((out * maxSlippage) / 1e18),
            path,
            address(this),
            block.timestamp + 40 seconds
        );
        emit Swap(path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
        return amounts[amounts.length - 1];
    }
}
