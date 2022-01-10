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

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "contracts/interface/uniswap/IUniswapV2Router02.sol";

/**
 * @notice The official Bifrost data
 */
contract BifrostSettings is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    /************************ Sale Settings  ***********************/

    // The flat fee in BNB (1e17 = 0.1 BNB)
    uint256 public listingFee;

    // The percentage fee for raised funds (only applicable for successful sales) (100 = 1%)
    uint256 public launchingFee;

    // The minimum liquidity percentage (5000 = 50%)
    uint256 public minLiquidityPercentage;

    // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
    uint256 public minCapRatio;

    // The minimum amount of time in seconds before liquidity can be unlocked
    uint256 public minUnlockTimeSeconds;

    // The minimum amount of time in seconds a sale has to run for
    uint256 public minSaleTime;

    // If set, the maximum amount of time a sale has to run for
    uint256 public maxSaleTime;

    /************************ Stats  ***********************/

    /// @notice Total amount of BNB raised
    uint256 public totalRaised;

    /// @notice Total amount of launched projects
    uint256 public totalProjects;

    /// @notice Total amount of people partcipating
    uint256 public totalParticipants;

    /// @notice Total liquidity locked
    uint256 public totalLiquidityLocked;

    /// @notice How much has been saved in discounts
    uint256 public savedInDiscounts;

    /// @notice List of sales launch status
    mapping(address => bool) public launched;


    /// @notice Bifrost Router address
    address public bifrostRouter;

    /// @notice The address of the router; this can be pancake or uniswap depending on the network
    IUniswapV2Router02 public exchangeRouter;

    /// @notice Bifrost Sale Implementation
    address public saleImpl;

    /// @notice Whitelist Implementation
    address public whitelistImpl;

    /// @notice Proxy admin
    address public proxyAdmin;

    /**
     * @notice The constructor for the router
     */
    function initialize(IUniswapV2Router02 _exchangeRouter, address _proxyAdmin, address _saleImpl, address _whitelistImpl) external initializer {
        __Ownable_init();

        // = IPancakeRouter02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); //0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3  0x10ED43C718714eb63d5aA57B78B54704E256024E
        exchangeRouter = _exchangeRouter;
        saleImpl = _saleImpl;
        whitelistImpl = _whitelistImpl;
        proxyAdmin = _proxyAdmin;

        listingFee = 1e17;
        launchingFee = 100;
        minLiquidityPercentage = 5000;
        minCapRatio = 5000;
        minUnlockTimeSeconds = 30 days;
        minSaleTime = 1 hours;
        maxSaleTime = 0;
    }

    /**
     * @notice SETTERS
     */
    function setExchangeRouter(IUniswapV2Router02 _exchangeRouter) external onlyOwner {
        exchangeRouter = _exchangeRouter;
    }

    function setSaleImpl(address _saleImpl) external onlyOwner {
        saleImpl = _saleImpl;
    }

    function setWhitelistImpl(address _whitelistImpl) external onlyOwner {
        whitelistImpl = _whitelistImpl;
    }

    function setProxyAdmin(address _proxyAdmin) external onlyOwner {
        proxyAdmin = _proxyAdmin;
    }

    function setBifrostRouter(address _bifrostRouter) external onlyOwner {
        bifrostRouter = _bifrostRouter;
    }

    function setListingFee(uint256 _listingFee) external onlyOwner {
        listingFee = _listingFee;
    }

    function setLaunchingFee(uint256 _launchingFee) external onlyOwner {
        launchingFee = _launchingFee;
    }

    function setMinimumLiquidityPercentage(uint256 _liquidityPercentage) external onlyOwner {
        minLiquidityPercentage = _liquidityPercentage;
    }

    function setMinimumCapRatio(uint256 _minimumCapRatio) external onlyOwner {
        minCapRatio = _minimumCapRatio;
    }

    function setMinimumUnlockTime(uint256 _minimumLiquidityUnlockTime) external onlyOwner {
        minUnlockTimeSeconds = _minimumLiquidityUnlockTime;
    }

    function setMinimumSaleTime(uint256 _minSaleTime) external onlyOwner {
        minSaleTime = _minSaleTime;
    }

    /**
     * @notice Get listing fee in token price
     */
    function listingFeeInToken(address token) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = exchangeRouter.WETH();
        uint256[] memory amounts = exchangeRouter.getAmountsIn(listingFee, path);
        return amounts[0];
    }

    /**
     * @notice Reflect launch status
     */
    function launch(address sale, uint256 raised, uint256 participants) external {
        require(_msgSender() == bifrostRouter, "Can only be called by the router");
        require(!launched[sale], "Youve already called this!");
        launched[sale] = true;

        totalProjects = totalProjects.add(1);
        totalRaised = totalRaised.add(raised);
        totalParticipants = totalParticipants.add(participants);
    }

    /**
     * @notice Sum up discount amount
     */
    function increaseDiscounts(uint256 amount) external {
        require(_msgSender() == bifrostRouter, "Can only be called by the router");
        savedInDiscounts = savedInDiscounts.add(amount);
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
    ) external view {
        require(liquidity >= minLiquidityPercentage, "Liquidity percentage below minimum");
        require(soft.mul(1e5).div(hard).div(10) >= minCapRatio, "Soft cap too low compared to hard cap");
        require(start > block.timestamp, "Sale time cant start in the past!");
        require(end > start, "Sale end has to be in the future from sale start");
        require(maxSaleTime == 0 || end.sub(start) < maxSaleTime, "Sale time too long");
        require(end.sub(start).add(1) >= minSaleTime, "Sale time too short");
        require(unlockTime >= minUnlockTimeSeconds, "Minimum unlock time is too low");

    }
}