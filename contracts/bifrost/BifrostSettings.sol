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

/**
 * @notice The official Bifrost data
 */
contract BifrostSettings is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;

    /**
     * @notice Stats
     */
    uint256 _totalRaised;          // Total amount of BNB raised
    uint256 _totalProjects;        // Total amount of launched projects
    uint256 _totalParticipants;    // Total amount of people partcipating
    uint256 _totalLiquidityLocked; // Total liquidity locked
    uint256 _savedInDiscounts;     // How much has been saved in discounts

    mapping (address => bool) _called;

    /**
     * @notice Sale Settings - these settings are used to ensure the configuration is compliant with what is fair for developers and users
     */
    uint256 public _listingFee;             // The flat fee in BNB
    uint256 public _launchingFee;           // The percentage fee for raised funds (only applicable for successful sales)
    uint256 public _minLiquidityPercentage; // The minimum liquidity percentage (5000 = 50%)
    uint256 public _minCapRatio;            // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
    uint256 public _minUnlockTimeSeconds;   // The minimum amount of time in seconds before liquidity can be unlocked
    uint256 public _minSaleTime;            // The minimum amount of time in seconds a sale has to run for

    /**
     * @notice The constructor for the router
     */
    constructor (
        uint256 listingFee, 
        uint256 launchingFee, 
        uint256 minLiquidityPercentage, 
        uint256 minCapRatio, 
        uint256 minUnlockTime,
        uint256 minSaleTime
    ) {
        _listingFee             = listingFee;    // The flat fee in BNB (1e17 = 0.1 BNB)
        _launchingFee           = launchingFee;     // The percentage of fees returned to the router owner for successful sales (100 = 1%)
        _minLiquidityPercentage = minLiquidityPercentage;    // The minimum liquidity percentage (5000 = 50%)
        _minCapRatio            = minCapRatio;    // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
        _minUnlockTimeSeconds   = minUnlockTime; // The minimum amount of time before liquidity can be unlocked
        _minSaleTime            = minSaleTime; // The minimum amount of time a sale has to run for
    }

    function launch(address token, uint256 raised, uint256 participants) external {
        require(!_called[token], "Youve already called this!");
        _totalProjects = _totalProjects.add(1);
        _totalRaised = _totalRaised.add(raised);
        _totalParticipants = _totalParticipants.add(participants);
        _called[token] = true;
    }

    function increaseDiscounts(uint256 amount) external {
        _savedInDiscounts = _savedInDiscounts.add(amount);
    }

    /**
     * @notice Validates the parameters against the data contract
     */
    function validate(
        uint256 soft, 
        uint256 hard, 
        uint256 liquidity, 
        uint256 start, 
        uint256 end, 
        uint256 unlockTime
    ) public view {
        require(liquidity >= _minLiquidityPercentage, "Liquidity percentage below minimum");
        require(soft.mul(1e5).div(hard).div(10) >= _minCapRatio, "Soft cap too low compared to hard cap");
        require(start > block.timestamp, "Sale time cant start in the past!");
        require(end > start, "Sale end has to be in the future from sale start");
        require(end.sub(start).add(1) >= _minSaleTime, "Sale time too short");
        require(unlockTime >= _minUnlockTimeSeconds, "Minimum unlock time is too low");
    }

    /**
     * @notice GETTERS AND SETTERS
     */
    function setListingFee(uint256 listingFee) external onlyOwner {
        _listingFee = listingFee;
    }

    function listingFee() public view returns (uint256) { return _listingFee; }

    function setLaunchingFee(uint256 launchingFee) external onlyOwner {
        _launchingFee = launchingFee;
    }

    function launchingFee() public view returns (uint256) {return _launchingFee;}

    function setMinimumLiquidityPercentage(uint256 liquidityPercentage) external onlyOwner {
        _minLiquidityPercentage = liquidityPercentage;
    }

    function minimumLiquidityPercentage() public view returns (uint256) {return _minLiquidityPercentage;}

    function setMinimumCapRatio(uint256 minimumCapRatio) external onlyOwner {
        _minCapRatio = minimumCapRatio;
    }

    function capRatio() public view returns (uint256) {return _minCapRatio;}

    function setMinimumUnlockTime(uint256 minimumLiquidityUnlockTime) external onlyOwner {
        _minUnlockTimeSeconds = minimumLiquidityUnlockTime;
    }

    function minimumUnlockTimeSeconds() public view returns (uint256) {return _minUnlockTimeSeconds;}

    function setMinimumSaleTime(uint256 minSaleTime) external onlyOwner {
        _minSaleTime = minSaleTime;
    }

    function minimumSaleTime() public view returns (uint256) {return _minSaleTime;}
}