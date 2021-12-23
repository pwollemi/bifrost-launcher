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

interface IBifrostSettings {
    /************************ Sale Settings  ***********************/

    function listingFee() external view returns (uint256);

    function listingFeeInToken(address) external view returns (uint256);

    function launchingFee() external view returns (uint256);

    function minLiquidityPercentage() external view returns (uint256);

    function minCapRatio() external view returns (uint256);

    function minUnlockTimeSeconds() external view returns (uint256);

    function minSaleTime() external view returns (uint256);

    function maxSaleTime() external view returns (uint256);

    /************************ Stats  ***********************/

    function totalRaised() external view returns (uint256);

    function totalProjects() external view returns (uint256);

    function totalParticipants() external view returns (uint256);

    function totalLiquidityLocked() external view returns (uint256);

    function savedInDiscounts() external view returns (uint256);

    /************************ Setters  ***********************/

    function setRouter(address _router) external;

    function setListingFee(uint256 _listingFee) external;

    function setLaunchingFee(uint256 _launchingFee) external;

    function setMinimumLiquidityPercentage(uint256 _liquidityPercentage) external;

    function setMinimumCapRatio(uint256 _minimumCapRatio) external;

    function setMinimumUnlockTime(uint256 _minimumLiquidityUnlockTime) external;

    function setMinimumSaleTime(uint256 _minSaleTime) external;


    function exchangeRouter() external view returns (address);

    function saleImpl() external view returns (address);

    function whitelistImpl() external view returns (address);


    function launch(address token, uint256 raised, uint256 participants) external;

    function increaseDiscounts(uint256 amount) external;

    function validate(
        uint256 soft, 
        uint256 hard, 
        uint256 liquidity, 
        uint256 start, 
        uint256 end, 
        uint256 unlockTime
    ) external view;
}