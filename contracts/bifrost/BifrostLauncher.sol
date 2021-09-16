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

import 'contracts/openzeppelin-contracts/Address.sol';
import 'contracts/openzeppelin-contracts/Context.sol';
import 'contracts/openzeppelin-contracts/Ownable.sol';
import 'contracts/openzeppelin-contracts/SafeMath.sol';
import 'contracts/openzeppelin-contracts/IERC20.sol';
import 'contracts/pancakeswap/IPancakeRouter02.sol';
import 'contracts/pancakeswap/IPancakeFactory.sol';
import 'contracts/uniswap/TransferHelper.sol';

import "hardhat/console.sol";

/**
 * @notice The official Bifrost launcher contract responsible for taking the liquidity from a successful sale and launching it.
 */
contract BifrostLauncher is Context, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint;

    IPancakeRouter02 public _pancakeswapV2Router;   // The address of the router
    address public _pancakeswapV2LiquidityPair;     // The address of the LP token

    address public _saleOwner;
    bool    public _isNative;
    address public _tokenA;
    address public _tokenB;
    uint    public _unlock;

    /**
     * @notice Checks if the caller is the sale owner or the router
     */
    modifier isAdmin {
        require(owner() == msg.sender || _saleOwner == msg.sender, "Caller isnt an admin");
        _;
    }

    /**
     * @notice Constructs an instance of BifrostLauncher
     * @param saleOwner The sale owner
     * @param isNative If false, the sale is backed by tokenB
     * @param tokenA The address of the token being sold
     * @param tokenB The address of the token raised
     * @param unlock The block timesamp when the LP tokens 
     */
    constructor(address saleOwner, bool isNative, address tokenA, address tokenB, uint unlock) {
        _saleOwner = saleOwner;
        _isNative = isNative;
        _tokenA = tokenA;
        _tokenB = tokenB;
        _unlock = unlock;
        _pancakeswapV2Router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    /**
     * @notice Launches the liquidity
     */
    function launch(uint256 aAmount, uint256 bAmount) external {
        if (_isNative) {
            console.log("Launching native");
            TransferHelper.safeApprove(_tokenA, msg.sender, aAmount);
            TransferHelper.safeTransferFrom(_tokenA, msg.sender, address(this), aAmount);
            _pancakeswapV2LiquidityPair = IPancakeFactory(_pancakeswapV2Router.factory()).createPair(_tokenA, _pancakeswapV2Router.WETH());
            addLiquidityBNB(_tokenA, aAmount, bAmount);
        } else {
            console.log("Launching TokenB");
            TransferHelper.safeApprove(_tokenA, msg.sender, aAmount);
            TransferHelper.safeApprove(_tokenB, msg.sender, bAmount);
            TransferHelper.safeTransferFrom(_tokenA, msg.sender, address(this), aAmount);
            TransferHelper.safeTransferFrom(_tokenB, msg.sender, address(this), bAmount);
            _pancakeswapV2LiquidityPair = IPancakeFactory(_pancakeswapV2Router.factory()).createPair(_tokenA, _tokenB);
            addLiquidity(_tokenA, aAmount, _tokenB, bAmount);
        }
    }

    /**
     * @notice Adds A/BNB liquidity to the PancakeSwap V2 LP
     */
    function addLiquidityBNB(address aToken, uint256 aAmount, uint256 bAmount) private {
        TransferHelper.safeApprove(aToken, address(_pancakeswapV2Router), aAmount);
        _pancakeswapV2Router.addLiquidityETH{value: bAmount}(aToken, aAmount, 0, 0, address(this), block.timestamp.add(300));
    }

    /**
     * @notice Adds A/B liquidity to the PancakeSwap V2 LP
     */
    function addLiquidity(address aToken, uint256 aAmount, address bToken, uint256 bAmount) internal {
        TransferHelper.safeApprove(aToken, address(_pancakeswapV2Router), aAmount);
        TransferHelper.safeApprove(bToken, address(_pancakeswapV2Router), bAmount);
        _pancakeswapV2Router.addLiquidity(aToken, bToken, aAmount, bAmount, 0, 0, address(this), block.timestamp.add(300));
    }

    /**
     * @notice Returns true if the admin is able to withdraw the LP tokens
     */
    function canWithdrawLPTokens() public view returns(bool) {
        return _unlock > block.timestamp;
    }

    /**
     * @notice Lets the sale owner withdraw the LP tokens once the liquidity unlock date has progressed
     */
    function withdrawLiquidity() external isAdmin {
        require(canWithdrawLPTokens(), "Cant withdraw LP tokens yet");
        TransferHelper.safeTransfer(_pancakeswapV2LiquidityPair, msg.sender, IERC20(_pancakeswapV2LiquidityPair).balanceOf(address(this)));
    }
}