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

import 'contracts/bifrost/IBifrostRouter01.sol';
import 'contracts/bifrost/BifrostSale01.sol';
import 'contracts/bifrost/Whitelist.sol';
import 'contracts/chainlink/AggregatorV3Interface.sol';
import 'contracts/pancakeswap/IPancakePair.sol';
import 'contracts/pancakeswap/IPancakeFactory.sol';

/**
 * @notice The official Bifrost smart contract
 */
contract PriceFeed is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    IPancakeRouter02 public _pancakeswapV2Router;   // The address of the router

    mapping (address => address) public _aggregators;  // token => price feed of BNB, can be chainlink aggregator with BNB

    uint256 public _currentListingFee;

    /**
     * @notice The constructor for the router
     */
    constructor (uint256 listingFee) {
        _currentListingFee = listingFee;
        _pancakeswapV2Router = IPancakeRouter02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); //0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3  0x10ED43C718714eb63d5aA57B78B54704E256024E
    }
    
    /**
     * @notice Sets a token price feed of chainlink
     */
    function setPriceFeed(address token, address feed) external onlyOwner {
        _aggregators[token] = feed;
    }

    /**
     * @notice Sets a token price feed
     */
    function listingFeeInToken(address token) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = _pancakeswapV2Router.WETH();
        uint256[] memory amounts = _pancakeswapV2Router.getAmountsIn(_currentListingFee, path);
        return amounts[0];
    }
}