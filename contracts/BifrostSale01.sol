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
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "contracts/interface/uniswap/IUniswapV2Router02.sol";
import "contracts/interface/uniswap/IUniswapV2Factory.sol";
import "contracts/interface/IBifrostRouter01.sol";
import "contracts/interface/IBifrostSale01.sol";
import "contracts/interface/IBifrostSettings.sol";

import "contracts/libraries/TransferHelper.sol";

import "contracts/Whitelist.sol";

/**
 * @notice A Bifrost Sale
 */
contract BifrostSale01 is Initializable, ContextUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    /// @notice The BifrostRouter owner
    address public owner;

    /// @notice The person running the sale
    address public runner;

    /// @notice The BifrostRouter
    IBifrostRouter01 public bifrostRouter;

    /// @notice The address of the whitelist implementation
    address public whitelistImpl;

    /// @notice The address of the bifrostRouter
    IUniswapV2Router02 public exchangeRouter;

    /// @notice The address of the LP token
    address public lpToken;     

    /**
     * @notice Configuration
     */
    address   public token;         // The token that the sale is selling
    uint256   public softCap;       // The soft cap of BNB or tokenB 
    uint256   public hardCap;       // The hard cap of BNB or tokenB
    uint256   public min;           // The minimum amount of contributed BNB or tokenB
    uint256   public max;           // The maximum amount of contributed BNB or tokenB
    uint256   public presaleRate;   // How many tokenA is given per BNB or tokenB
    uint256   public listingRate;   // How many tokenA is worth 1 BNB or 1 tokenB when we list
    uint256   public liquidity;     // What perecentage of raised funds will be allocated for liquidity (100 = 1% - i.e. out of 10,000)
    uint256   public start;         // The start date in UNIX seconds of the presale
    uint256   public end;           // The end date in UNIX seconds of the presale
    uint256   public unlockTime;    // The time in seconds that the liquidity lock should last
    address   public whitelist;     // Whitelist contract address

    /**
     * @notice State Settings
     */
    bool public prepared;   // True when the sale has been prepared to start by the owner
    bool public launched;   // Whether the sale has been finalized and launched; inited to false by default
    bool public canceled;   // This sale is canceled

    /**
     * @notice Current Status - These are modified after a sale has been setup and is running
     */
    uint256 public totalTokens;                   // Total tokens determined for the sale
    uint256 public saleAmount;                    // How many tokens are on sale
    uint256 public liquidityAmount;               // How many tokens are allocated for liquidity
    uint256 public raised;                        // How much BNB has been raised
    mapping(address => uint256) public _deposited; // A mapping of addresses to the amount of BNB they deposited


    /********************** Modifiers **********************/

    /**
     * @notice Checks if the caller is the Bifrost owner, Sale owner or the bifrostRouter itself
     */
    modifier isAdmin {
        require(address(bifrostRouter) == _msgSender() || owner == _msgSender() || runner == _msgSender(), "Caller isnt an admin");
        _;
    }

    /**
     * @notice Checks if the caller is the Sale owner
     */
    modifier isRunner {
        require(runner == _msgSender(), "Caller isnt an runner");
        _;
    }

    /**
     * @notice Checks if the sale is running
     */
    modifier isRunning {
        require(running(), "Sale isn't running!");
        _;
    }

    modifier isSuccessful {
        require(successful(), "Sale isn't successful!");
        _;
    }

    /**
     * @notice Checks if the sale is finished
     */
    modifier isEnded {
        require(ended(), "Sale hasnt ended");
        _;
    }

    /**
     * @notice Checks if the sale has been finalized
     */
    modifier isLaunched {
        require(launched, "Sale hasnt been launched yet");
        _;
    }

    /********************** Functions **********************/

    /**
     * @notice Creates a bifrost sale
     */
    function initialize(
        address _bifrostRouter, 
        address _owner, 
        address _runner, 
        address _token,
        address _exchangeRouter,
        address _whitelistImpl,
        uint256 _unlockTime
    ) external initializer {
        __Context_init();

        // Set the owner of the sale to be the owner of the deployer 
        bifrostRouter = IBifrostRouter01(_bifrostRouter);
        owner = _owner;
        runner = _runner;
        token = _token;

        // Let the bifrostRouter control payments!
        TransferHelper.safeApprove(_token, _bifrostRouter, type(uint256).max);

        exchangeRouter = IUniswapV2Router02(_exchangeRouter);
        unlockTime = _unlockTime;
    }

    /**
     * @notice Configure a bifrost sale
     */
    function configure(IBifrostSale01.SaleParams memory params) external isAdmin {
        softCap = params.soft;
        hardCap = params.hard;
        min = params.min;
        max = params.max;
        presaleRate = params.presaleRate;
        listingRate = params.listingRate;
        liquidity = params.liquidity;
        start = params.start;
        end = params.end;

        // 1e18 is BNB decimals, we will need update to token's decimal later
        saleAmount      = presaleRate.mul(hardCap).div(1e18);
        liquidityAmount = listingRate.mul(hardCap).div(1e18).mul(liquidity).div(1e4);
        totalTokens = saleAmount.add(liquidityAmount);

        if(params.whitelisted) {
            whitelist = ClonesUpgradeable.clone(whitelistImpl);
        }
    }

    /**
     * @notice If the presale isn't running will direct any received payments straight to the bifrostRouter
     */
    receive() external payable {
        _deposit(_msgSender(), msg.value);
    }

    function resetWhitelist() external isAdmin {
        if (whitelist != address(0)) {
            whitelist = ClonesUpgradeable.clone(whitelistImpl);
        }
    }

    function deposited() external view returns (uint256) {
        return accountsDeposited(_msgSender());
    }

    function accountsDeposited(address account) public view returns (uint256) {
        return _deposited[account];
    }

    function setRunner(address _runner) external isAdmin {
        runner = _runner;
    }

    function getRunner() external view returns (address) {
        return runner;
    }

    function isWhitelisted() external view returns(bool) {
        return whitelist != address(0);
    }

    function userWhitelisted() external view returns(bool) {
        return _userWhitelisted(_msgSender());
    }

    function _userWhitelisted(address account) public view returns(bool) {
        if (whitelist != address(0)) {
            return Whitelist(whitelist).isWhitelisted(account);
        } else {
            return false;
        }
    }

    function setWhitelist() external isRunner {
        require(block.timestamp < start, "Sale started");
        require(whitelist == address(0), "There is already a whitelist!");
        whitelist = address(new Whitelist());
    }

    function removeWhitelist() external isRunner {
        require(block.timestamp < start, "Sale started");
        require(whitelist != address(0), "There isn't a whitelist set");
        whitelist = address(0);
    }

    function addToWhitelist(address[] memory users) external isRunner {
        require(block.timestamp < start, "Sale started");
        Whitelist(whitelist).addToWhitelist(users);
    }

    function removeFromWhitelist(address[] memory addrs) external isRunner {
        require(block.timestamp < start, "Sale started");
        Whitelist(whitelist).removeFromWhitelist(addrs);
    }

    function cancel() external isAdmin {
        require(block.timestamp < start, "Sale started");
        canceled = true;
    }

    /**
     * @notice For users to deposit into the sale
     * @dev This entitles _msgSender() to (amount * presaleRate) after a successful sale
     */
    function deposit() external payable isRunning {
        _deposit(_msgSender(), msg.value);
    }

    /**
     * @notice 
     */
    function _deposit(address user, uint256 amount) internal {
        require(!canceled, "Sale is canceled");
        require(running(), "Sale isn't running!");
        require(canStart(), "Token balance isn't topped up!");
        require(amount >= min, "Amount must be above min");
        require(amount <= max, "Amount must be below max");

        require(raised.add(amount) <= hardCap, "Cant exceed hard cap");
        require(_deposited[user].add(amount) <= max, "Cant deposit more than the max");
        if (whitelist != address(0)) {
            require(Whitelist(whitelist).isWhitelisted(user), "User not whitelisted");
        }
        _deposited[user] = _deposited[user].add(amount);
        raised = raised.add(amount);
    }

    /**
     * @notice Finishes the sale, and if successful launches to PancakeSwap
     */
    function finalize() external isAdmin isSuccessful {
        end = block.timestamp;

        // First take the developer cut
        uint256 devBnb   = raised.mul(bifrostRouter.launchingFee()).div(1e4);
        uint256 devTokens = listingRate.mul(devBnb).div(1e18);
        TransferHelper.safeTransferETH(owner, devBnb);
        TransferHelper.safeTransfer(token, owner, devTokens);

        // Get 99% of BNB
        uint256 totalBNB = raised.sub(devBnb);

        // Find a percentage (i.e. 50%) of the leftover 99% liquidity
        uint256 liquidityBNB = totalBNB.mul(liquidity).div(1e4);
        uint256 tokensForLiquidity = listingRate.mul(liquidityBNB).div(1e18);

        // Add the tokens and the BNB to the liquidity pool, satisfying the listing rate as the starting price point
        TransferHelper.safeApprove(token, address(exchangeRouter), tokensForLiquidity);
        exchangeRouter.addLiquidityETH{value: liquidityBNB}(token, tokensForLiquidity, 0, 0, address(this), block.timestamp.add(300));
        lpToken = IUniswapV2Factory(exchangeRouter.factory()).getPair(token, exchangeRouter.WETH());

        // Send the sale runner the reamining eth and tokens 
        TransferHelper.safeTransferETH(_msgSender(), totalBNB.sub(liquidityBNB));
        TransferHelper.safeTransfer(token, _msgSender(), IERC20Upgradeable(token).balanceOf(address(this)));

        launched = true;
    }
 
    /**
     * @notice For users to withdraw from a sale
     * @dev This entitles _msgSender() to (amount * presaleRate) after a successful sale
     */
    function withdraw() external isEnded {
        require(_deposited[_msgSender()] > 0, "User didnt partake");

        uint256 amount = _deposited[_msgSender()];
        _deposited[_msgSender()] = 0;

        // Give the user their tokens
        if(successful()) {
            require(launched, "Sale hasnt finalized");
            uint256 tokens = amount.mul(presaleRate).div(1e18);
            TransferHelper.safeTransfer(token, _msgSender(), tokens);
        } else {
            // Otherwise return the user their BNB
            payable(_msgSender()).transfer(amount);
        }
    }

    /**
     * @notice EMERGENCY USE ONLY: Lets the owner of the sale reclaim any stuck funds
     */
    function reclaim() external view {
        require(address(bifrostRouter) == _msgSender() || owner == _msgSender(), "User not Bifrost");
    }

    /**
     * @notice Returns true if the admin is able to withdraw the LP tokens
     */
    function canWithdrawLiquidity() public view returns(bool) {
        return end.add(unlockTime) <= block.timestamp;
    }

    /**
     * @notice Lets the sale owner withdraw the LP tokens once the liquidity unlock date has progressed
     */
    function withdrawLiquidity() external isAdmin {
        require(canWithdrawLiquidity(), "Cant withdraw LP tokens yet");
        TransferHelper.safeTransfer(lpToken, _msgSender(), IERC20Upgradeable(lpToken).balanceOf(address(this)));
    }

    /**
     * @notice Withdraws BNB from the contract
     */
    function emergencyWithdrawBNB() payable external {
        require(block.timestamp > end.add(48 hours), "Can only call 48-hours after sales ended");
        require(owner == _msgSender(), "Only owner");
        payable(owner).transfer(address(this).balance);
    }

    /**
     * @notice Withdraws tokens that are stuck
     */
    function emergencyWithdrawTokens(address _token) payable external {
        require(block.timestamp > end.add(48 hours), "Can only call 48-hours after sales ended");
        require(owner == _msgSender(), "Only owner");
        TransferHelper.safeTransfer(_token, owner, IERC20Upgradeable(_token).balanceOf(address(this)));
    }

    function successful() public view returns(bool) {
        return raised >= softCap;
    }

    function running() public view returns(bool) {
        return block.timestamp >= start && block.timestamp < end;
    }

    function ended() public view returns(bool) {
        return block.timestamp >= end || launched;
    }

    function canStart() public view returns(bool) {
        return IERC20Upgradeable(token).balanceOf(address(this)) >= totalTokens;
    }
}

