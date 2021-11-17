// SPDX-License-Identifier: MIT
//
// Copyright of The $RAINBOW Team
//  ____  _  __               _   
// |  _ \(_)/ _|             | |  
// | |_) |_| |_ _ __ ___  ___| |_ 
// |  _ <| |  _| '__/ _ \/ __| __|
// | |_) | | | | | | (_) \__ \ |_ 
// |____/|_|_| |_|  \___/|___/\__|
//                               

pragma solidity ^0.8.4;

import 'contracts/openzeppelin/Address.sol';
import 'contracts/openzeppelin/Context.sol';
import 'contracts/openzeppelin/Ownable.sol';
import 'contracts/openzeppelin/SafeMath.sol';
import 'contracts/openzeppelin/IERC20.sol';
import 'contracts/pancakeswap/IPancakeRouter02.sol';
import 'contracts/pancakeswap/IPancakeFactory.sol';
import 'contracts/uniswap/TransferHelper.sol';

import "hardhat/console.sol";

import 'contracts/bifrost/IBifrostLauncher.sol';

/**
 * @notice The official Bifrost launcher contract responsible for taking the liquidity from a successful sale and launching it.
 */
contract BifrostLauncher is IBifrostLauncher, Context, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint;

    IPancakeRouter02 public _pancakeswapV2Router;   // The address of the router
    address public _pancakeswapV2LiquidityPair;     // The address of the LP token

    address public _saleAddress;
    address public _saleOwner;
    address public _saleToken;
    uint    public _unlock;
    bool    public _launched;

    /**
     * @notice Checks if the caller is the sale owner or the router
     */
    modifier isAdmin {
        require(owner() == msg.sender || _saleOwner == msg.sender, "Caller isnt an admin");
        _;
    }

    /**
     * @notice Constructs an instance of BifrostLauncher
     */
    constructor(address saleAddress, address saleOwner, address saleToken, uint unlock) {
        _saleAddress = saleAddress;
        _saleOwner = saleOwner;
        _saleToken = saleToken;
        _unlock = unlock;
        _pancakeswapV2Router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _launched = false;
    }

    /**
     * @notice Launches to PancakeSwap V2
     * @dev tokenAmount comes by param, bnb amount is paid to the function
     */
    function launch(uint256 tokenAmount) override external payable isAdmin {

        // Transfer the full balance of BNB from the sale to the launcher
        // TransferHelper.safeTransferETH(address(this), bnbAmount);

        // Transfer the full balance of tokens from the sale to the launcher
        TransferHelper.safeTransferFrom(_saleToken, _saleAddress, address(this), tokenAmount);

        // Approve PancakeSwap Router to spend our tokens
        TransferHelper.safeApprove(_saleToken, address(_pancakeswapV2Router), tokenAmount);
        _pancakeswapV2Router.addLiquidityETH{value: msg.value}(_saleToken, tokenAmount, 0, 0, address(this), block.timestamp.add(300));
        _pancakeswapV2LiquidityPair = IPancakeFactory(_pancakeswapV2Router.factory()).getPair(_saleToken, _pancakeswapV2Router.WETH());

        _launched = true;
    }

    function launched() override external view returns(bool) {
        return _launched;
    }

    /**
     * @notice Returns true if the admin is able to withdraw the LP tokens
     */
    function canWithdrawLiquidity() override public view returns(bool) {
        return _unlock > block.timestamp;
    }

    /**
     * @notice Lets the sale owner withdraw the LP tokens once the liquidity unlock date has progressed
     */
    function withdrawLiquidity() override external isAdmin {
        require(canWithdrawLiquidity(), "Cant withdraw LP tokens yet");
        TransferHelper.safeTransfer(_pancakeswapV2LiquidityPair, msg.sender, IERC20(_pancakeswapV2LiquidityPair).balanceOf(address(this)));
    }
}