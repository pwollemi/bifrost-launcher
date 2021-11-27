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
        uint256 bnbAmountOfOneToken = type(uint256).max;
        uint256 decimals = 18; // price decimals

        if (_aggregators[token] != address(0)) { // if chainlink aggregator is set
            AggregatorV3Interface aggregator = AggregatorV3Interface(_aggregators[token]);
            (, int256 answer, , , ) = aggregator.latestRoundData();
            require(answer > 0, "Invalid price feed");
            decimals = aggregator.decimals();
            bnbAmountOfOneToken = uint256(answer);
        } else { // use pancake pair
            IPancakePair pair = IPancakePair(IPancakeFactory(_pancakeswapV2Router.factory()).getPair(token, _pancakeswapV2Router.WETH()));
            address token0 = pair.token0();
            address token1 = pair.token1();
            uint256 decimals0 = IERC20(token0).decimals();
            uint256 decimals1 = IERC20(token1).decimals();

            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            // avoid mul and div by 0
            if (reserve0 > 0 && reserve1 > 0) {
                if (token == token0) {
                    bnbAmountOfOneToken = (10**(decimals + decimals0 - decimals1) * uint256(reserve1)) / uint256(reserve0);
                } else {
                    bnbAmountOfOneToken = (10**(decimals + decimals1 - decimals0) * uint256(reserve0)) / uint256(reserve1);
                }
            }
        }
        return _currentListingFee * (10 ** decimals) / uint256(bnbAmountOfOneToken);
    }

}