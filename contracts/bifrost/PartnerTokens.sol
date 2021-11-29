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
import 'contracts/bifrost/PriceFeed.sol';

/**
 * @notice The official Bifrost smart contract
 */
contract PartnerTokens is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;

    struct Partner {
        bool    valid;    // Whether or not this is a valid partner token
        uint256 discount; // Default 0
    }

    mapping (address => Partner) public _partnerTokens; // A mapping of token contract addresses to a flag describing whether or not they can be used to pay a fee
   

    /**
     * @notice The constructor for the router
     */
    constructor () {
        
    }

    /**
     * @notice Sets a token as able to decide fees of Bifrost
     */
    function setPartnerToken(address token, uint256 discount) external onlyOwner {
        _partnerTokens[token].valid = true;
        _partnerTokens[token].discount = discount;
    }

    function removePartnerDiscount(address token) external onlyOwner {
        _partnerTokens[token].valid = false;
        _partnerTokens[token].discount = 0;
    }

    function getPartner(address token) external returns(bool, uint256) {
        return (_partnerTokens[token].valid, _partnerTokens[token].discount);
    }
}