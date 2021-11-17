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
 * @notice The Bifrost Router Interface
 */
interface IBifrostRouter01 {
    // Helper payment functions
    function withdrawBNB(uint256 amount) external;
    function withdrawForeignToken(address token) external;

    // Bifrost interface
    function setPriceFeed(address token, address feed) external;
    function setPartnerToken(address token, bool b) external;
    function payFee(address token) external;
    function length() external view returns(uint256);
    function validate(
        uint256 soft, 
        uint256 hard, 
        uint256 liquidity, 
        uint256 start, 
        uint256 end, 
        uint256 unlockTime
    ) external view;
    function createSale(
        address token, 
        uint256 soft, 
        uint256 hard, 
        uint256 min, 
        uint256 max, 
        uint256 presaleRate, 
        uint256 listingRate, 
        uint256 liquidity, 
        uint256 start, 
        uint256 end, 
        uint256 unlockTime
    ) external payable;
}