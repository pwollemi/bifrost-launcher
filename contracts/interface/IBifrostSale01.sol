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

/**
 * @notice A Bifrost Sale
 */
interface IBifrostSale01 {
    struct SaleParams {
        uint256 soft;
        uint256 hard; 
        uint256 min;
        uint256 max;
        uint256 presaleRate;
        uint256 listingRate;
        uint256 liquidity;
        uint256 start;
        uint256 end;
        uint256 unlockTime;
        bool    whitelisted;
    }

    function totalTokens() external view returns (uint256);

    function getRunner() external view returns (address);

    function setRunner(address runner) external;

    function canStart() external view returns (bool);

    function deposit() external payable;

    function finalize() external;

    function withdraw() external;

    function reclaim() external view;

    function launched() external view returns (bool);
}