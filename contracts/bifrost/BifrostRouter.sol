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
import "contracts/bifrost/BifrostSale.sol";

/**
 * @notice The official Bifrost smart contract
 */
contract BifrostRouter is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    mapping (address => Sale) public sales;
    Sale[] public saleList;

    /**
     * @notice Sale Settings - these settings are used to ensure the configuration is compliant with what is fair for developers and users
     */
    uint256 public _listingFee             = 1e17;    // The flat fee in BNB (1e17 = 0.1 BNB)
    uint256 public _launchingFee           = 100;     // The percentage of fees returned to the router owner for successful sales (100 = 1%)
    uint256 public _minLiquidityPercentage = 5000;    // The minimum liquidity percentage (5000 = 50%)
    uint256 public _minCapRatio            = 5000;    // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
    uint256 public _minUnlockTime          = 30 days; // The minimum amount of time before liquidity can be unlocked
    uint256 public _minSaleTime            = 1 hours; // The minimum amount of time a sale has to run for
    uint256 public _maxSaleTime            = 0;       // If set, the maximum amount of time a sale has to run for
    
    /**
     * @notice A structure for a sale
     */
    struct Sale {
        bool        valid;          // Whether there is a sale
        BifrostSale saleContract;   // The address of the sale contract
    }
    
    constructor () {

    }
    
    /**
     * @notice Required to recieve BNB from PancakeSwap V2 Router when swaping
     */
    receive() external payable {
        payable(owner()).transfer(address(this).balance);
    }
    
    /**
     * @notice Withdraws BNB from the contract
     */
    function withdrawBNB(uint256 amount) public onlyOwner {
        if(amount == 0) payable(owner()).transfer(address(this).balance);
        else payable(owner()).transfer(amount);
    }
    
    /**
     * @notice Withdraws non-RAINBOW tokens that are stuck as to not interfere with the liquidity
     */
    function withdrawForeignToken(address token) public onlyOwner {
        require(address(this) != address(token), "Cannot withdraw native token");
        IERC20(address(token)).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }
    
    /**
     * @notice Transfers BNB to an address
     */
    function transferBNBToAddress(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }
    
    /**
     * @notice Called by anyone who wishes to begin their own token sale
     */
    function createSale(bool useWhitelist, bool useNative) public {
        require(!sales[msg.sender].valid, "This wallet is already managing a sale!");
        sales[msg.sender].valid        = true;
        sales[msg.sender].saleContract = new BifrostSale(payable(address(this)), msg.sender, useWhitelist, useNative);
        saleList.push(sales[msg.sender]);
    }
    
    /**
     * @notice GETTERS AND SETTERS
     */
    function setListingFee(uint256 listingFee) external onlyOwner {
        _listingFee = listingFee;
    }
    function listingFee() external view returns (uint256) { return _listingFee; }

    function setLaunchingFee(uint256 launchingFee) external onlyOwner {
        _launchingFee = launchingFee;
    }
    function launchingFee() external view returns (uint256) {return _launchingFee;}

    function setMinimumLiquidityPercentage(uint256 liquidityPercentage) external onlyOwner {
        _minLiquidityPercentage = liquidityPercentage;
    }
    function minimumLiquidityPercentage() external view returns (uint256) {return _minLiquidityPercentage;}

    function setMinimumCapRatio(uint256 minimumCapRatio) external onlyOwner {
        _minCapRatio = minimumCapRatio;
    }
    function capRatio() external view returns (uint256) {return _minCapRatio;}

    function setMinimumUnlockTime(uint256 minimumLiquidityUnlockTime) external onlyOwner {
        _minUnlockTime = minimumLiquidityUnlockTime;
    }
    function minimumUnlockTime() external view returns (uint256) {return _minUnlockTime;}

    function setMinimumSaleTime(uint256 minSaleTime) external onlyOwner {
        _minSaleTime = minSaleTime;
    }
    function minimumSaleTime() external view returns (uint256) {return _minSaleTime;}

    function setMaximumSaleTime(uint256 maxSaleTime) external onlyOwner {
        _maxSaleTime = maxSaleTime;
    }
    function maximumSaleTime() external view returns (uint256) {return _maxSaleTime;}
}