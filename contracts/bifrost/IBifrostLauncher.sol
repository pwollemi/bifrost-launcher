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
 * @notice Declares the functions that the Bifrost Launcher uses
 */
interface IBifrostLauncher {
    function launch(uint256) external payable;
    function launched() external view returns(bool);
    function canWithdrawLiquidity() external view returns(bool);
    function withdrawLiquidity() external;
}