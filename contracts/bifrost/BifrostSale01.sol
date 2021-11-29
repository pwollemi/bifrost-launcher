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
import 'contracts/pancakeswap/IPancakeRouter02.sol';
import 'contracts/pancakeswap/IPancakeFactory.sol';
import 'contracts/uniswap/TransferHelper.sol';

import 'contracts/bifrost/IBifrostRouter01.sol';
import 'contracts/bifrost/IBifrostSale01.sol';
import 'contracts/bifrost/Whitelist.sol';

import "hardhat/console.sol";

/**
 * @notice A Bifrost Sale
 */
contract BifrostSale01 is IBifrostSale01, Context {
    using SafeMath for uint256;
    using Address for address;

    IBifrostRouter01 public _router;        // The BifrostRouter
    address payable public  _routerAddress; // The BifrostRouter address
    address public          _owner;         // The BifrostRouter owner
    address public          _runner;        // The person running the sale

    /**
     * @notice State Settings
     */
    bool public _prepared;   // True when the sale has been prepared to start by the owner
    bool public _launched;   // Whether the sale has been finalized and launched
    bool public _canceled;   // This sale is canceled

    /**
     * @notice Launch Settings
     */
    IPancakeRouter02 public _pancakeswapV2Router;   // The address of the router
    address public _pancakeswapV2LiquidityPair;     // The address of the LP token

    /**
     * @notice Checks if the caller is the Bifrost owner, Sale owner or the router itself
     */
    modifier isAdmin {
        require(_routerAddress == msg.sender || _owner == msg.sender || _runner == msg.sender, "Caller isnt an admin");
        _;
    }

    /**
     * @notice Checks if the caller is the Sale owner
     */
    modifier isRunner {
        require(_routerAddress == msg.sender || _owner == msg.sender || _runner == msg.sender, "Caller isnt an runner");
        _;
    }

    /**
     * @notice Checks if the sale is running
     */
    modifier isRunning {
        require(running(), "Sale isnt running");
        _;
    }

    function running() public view returns(bool) {
        return block.timestamp >= _start && block.timestamp < _end;
    }

    modifier isSuccessful {
        require(successful(), "Sale isn't successful!");
        _;
    }

    function successful() public view returns(bool) {
        return _raised >= _softCap;
    }

    /**
     * @notice Checks if the sale is finished
     */
    modifier isEnded {
        require(ended(), "Sale hasnt ended");
        _;
    }

    function ended() public view returns(bool) {
        return block.timestamp >= _end || _launched;
    } 

    /**
     * @notice Checks if the sale has been finalized
     */
    modifier isLaunched {
        require(_launched, "Sale hasnt been launched yet");
        _;
    }

    /**
     * @notice Configuration
     */
    address   public _token;         // The token that the sale is selling
    uint256   public _softCap;       // The soft cap of BNB or tokenB 
    uint256   public _hardCap;       // The hard cap of BNB or tokenB
    uint256   public _min;           // The minimum amount of contributed BNB or tokenB
    uint256   public _max;           // The maximum amount of contributed BNB or tokenB
    uint256   public _presaleRate;   // How many tokenA is given per BNB or tokenB
    uint256   public _listingRate;   // How many tokenA is worth 1 BNB or 1 tokenB when we list
    uint256   public _liquidity;     // What perecentage of raised funds will be allocated for liquidity (100 = 1% - i.e. out of 10,000)
    uint256   public _start;         // The start date in UNIX seconds of the presale
    uint256   public _end;           // The end date in UNIX seconds of the presale
    uint256   public _unlockTime;    // The time in seconds that the liquidity lock should last
    address   public _whitelist;     // Whitelist contract address

    /**
     * @notice TODO: SETTINGS TO IMPLEMENT
     */
    //bool      public _useNative;     // Whether the to pair with the fundamental crypto coin 
    //address   public _tokenB;        // The token that will be used if useNative is false

    /**
     * @notice Current Status - These are modified after a sale has been setup and is running
     */
    uint256 public _totalTokens;            // Total tokens determined for the sale
    uint256 public _saleAmount;             // How many tokens are on sale
    uint256 public _liquidityAmount;        // How many tokens are allocated for liquidity
    uint256 public _raised;                 // How much BNB has been raised
    mapping(address => uint256) public _deposited; // A mapping of addresses to the amount of BNB they deposited
    
    /**
     * @notice Creates a bifrost sale
     */
    constructor(
        address payable router, 
        address owner, 
        address runner, 
        address token,
        uint256 unlockTime
    ) {
        // Set the owner of the sale to be the owner of the deployer 
        _routerAddress = router;
        _router = IBifrostRouter01(router);
        _owner = owner;
        _runner  = runner;
        _token = token;

        // Let the router control payments!
        IERC20(token).approve(router, type(uint256).max);

        _pancakeswapV2Router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E); //0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3  0x10ED43C718714eb63d5aA57B78B54704E256024E
        _launched = false;
        _unlockTime = unlockTime;
    }

    function configure(
        uint256 soft, 
        uint256 hard, 
        uint256 min, 
        uint256 max, 
        uint256 presaleRate, 
        uint256 listingRate, 
        uint256 liquidity, 
        uint256 startTime, 
        uint256 endTime,
        bool    whitelisted
    ) external isAdmin {
        _softCap = soft;
        _hardCap = hard;
        _min = min;
        _max = max;
        _presaleRate = presaleRate;
        _listingRate = listingRate;
        _liquidity = liquidity;
        _start = startTime;
        _end = endTime;

        // 1e18 is BNB decimals, we will need update to token's decimal later
        _saleAmount      = _presaleRate.mul(_hardCap).div(1e18);
        _liquidityAmount = _listingRate.mul(_hardCap).div(1e18).mul(_liquidity).div(1e4);
        _totalTokens = _saleAmount.add(_liquidityAmount);

        if(whitelisted) {
            _whitelist = address(new Whitelist());
        }
    }

    /**
     * @notice If the presale isn't running will direct any received payments straight to the router
     */
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function totalTokens() override external view returns (uint256) {
        return _totalTokens;
    }

    function saleAmount() external view returns (uint256) {
        return _saleAmount;
    }
    
    function liquidityAmount() external view returns (uint256) {
        return _liquidityAmount;
    }

    function raised() external view returns (uint256) {
        return _raised;
    }

    function deposited() external view returns (uint256) {
        return accountsDeposited(msg.sender);
    }

    function accountsDeposited(address account) public view returns (uint256) {
        return _deposited[account];
    }

    function getRunner() override public view returns (address) {
        return _runner;
    }
    
    function setRunner(address runner) override external isAdmin {
        _runner = runner;
    }

    function canStart() override public view returns(bool) {
        return IERC20(_token).balanceOf(address(this)) >= _totalTokens;
    }

    function userWhitelisted() external returns(bool) {
        return _userWhitelisted(msg.sender);
    }

    function _userWhitelisted(address account) public returns(bool) {
        if (_whitelist != address(0)) {
            return Whitelist(_whitelist).isWhitelisted(account);
        } else {
            return false;
        }
    }

    function setWhitelist() external isRunner {
        require(_whitelist == address(0), "There is already a whitelist!");
        _whitelist = address(new Whitelist());
    }

    function removeWhitelist() external isRunner {
        require(_whitelist != address(0), "There isn't a whitelist set");
        _whitelist = address(0);
    }

    function addToWhitelist(address[] memory users) external isRunner {
        require(block.timestamp < _start, "Sale started");
        Whitelist(_whitelist).addToWhitelist(users);
    }

    function removeFromWhitelist(address[] memory addrs) external isRunner {
        require(block.timestamp < _start, "Sale started");
        Whitelist(_whitelist).removeFromWhitelist(addrs);
    }

    function cancel() external isAdmin {
        require(block.timestamp < _start, "Sale started");
        _canceled = true;
    }

    /**
     * @notice For users to deposit into the sale
     * @dev This entitles msg.sender to (amount * _presaleRate) after a successful sale
     */
    function deposit() override external payable isRunning {
        _deposit(msg.sender, msg.value);
    }

    /**
     * @notice Finishes the sale, and if successful launches to PancakeSwap
     */
    function finalize() override external isAdmin {
        require(successful(), "Cannot finalize sale yet!");
        _end = block.timestamp;

        // First take the developer cut
        uint256 devCut = _raised.mul(_router.launchingFee()).div(1e4);
        TransferHelper.safeTransferETH(_routerAddress, devCut);

        // Get the portion of liquidity from the leftovers
        uint256 totalBNB = _raised.sub(devCut);
        uint256 liquidityBNB = totalBNB.mul(_liquidity).div(1e4);
        uint256 actualLiquidity = _listingRate.mul(liquidityBNB).div(1e18);

        // Add liquidity
        TransferHelper.safeApprove(_token, address(_pancakeswapV2Router), actualLiquidity);
        _pancakeswapV2Router.addLiquidityETH{value: liquidityBNB}(_token, actualLiquidity, 0, 0, address(this), block.timestamp.add(300));
        _pancakeswapV2LiquidityPair = IPancakeFactory(_pancakeswapV2Router.factory()).getPair(_token, _pancakeswapV2Router.WETH());

        TransferHelper.safeTransfer(_token, msg.sender, IERC20(_token).balanceOf(address(this)));
        TransferHelper.safeTransferETH(msg.sender, totalBNB.sub(liquidityBNB));
        _launched = true;
    }
 
    /**
     * @notice For users to withdraw from a sale
     * @dev This entitles msg.sender to (amount * _presaleRate) after a successful sale
     */
    function withdraw() override external {
        require(ended(), "Sale hasn't ended");
        require(_deposited[msg.sender] > 0, "User didnt partake");

        uint256 amount = _deposited[msg.sender];

        // Give the user their tokens
        if(successful()) {
            uint256 tokens = amount.mul(_presaleRate).div(1e18);
            TransferHelper.safeTransfer(_token, msg.sender, tokens);
        } else {
            // Otherwise return the user their BNB
            payable(msg.sender).transfer(amount);
            _deposited[msg.sender].sub(amount);
        }
    }

    /**
     * @notice EMERGENCY USE ONLY: Lets the owner of the sale reclaim any stuck funds
     */
    function reclaim() override external view {
        require(_routerAddress == msg.sender || _owner == msg.sender, "User not Bifrost");
    }

    /**
     * @notice 
     */
    function _deposit(address user, uint256 amount) internal {
        require(!_canceled, "Sale is canceled");
        require(canStart(), "Token balance isn't topped up!");
        if (running()) {
            require(_raised.add(amount) <= _hardCap, "This amount would exceed the hard cap");
            require(_deposited[user].add(amount) <= _max, "Cannot contribute more than the max!");
            require(amount >= _min, "Amount must be above min");
            require(amount <= _max, "Amount must be below max");
            if (_whitelist != address(0)) {
                require(Whitelist(_whitelist).isWhitelisted(user), "User not whitelisted");
            }
            _deposited[user] = _deposited[user].add(amount);
            _raised = _raised.add(amount);
        } else {
            _routerAddress.transfer(amount);
        }
    }

    /**
     * @notice Returns true if the admin is able to withdraw the LP tokens
     */
    function canWithdrawLiquidity() public view returns(bool) {
        return _end.add(_unlockTime) <= block.timestamp;
    }

    /**
     * @notice Lets the sale owner withdraw the LP tokens once the liquidity unlock date has progressed
     */
    function withdrawLiquidity() external isAdmin {
        require(canWithdrawLiquidity(), "Cant withdraw LP tokens yet");
        TransferHelper.safeTransfer(_pancakeswapV2LiquidityPair, msg.sender, IERC20(_pancakeswapV2LiquidityPair).balanceOf(address(this)));
    }

    function token() external view returns(address) {
        return _token;
    }

    function softCap() external view returns(uint256) {
        return _softCap;
    }

    function hardCap() external view returns(uint256) {
        return _hardCap;
    }

    function min() external view returns(uint256) {
        return _min;
    }

    function max() external view returns(uint256) {
        return _max;
    }

    function presaleRate() external view returns(uint256) {
        return _presaleRate;
    }

    function listingRate() external view returns(uint256) {
        return _listingRate;
    }

    function liquidity() external view returns(uint256) {
        return _liquidity;
    }

    function start() external view returns(uint256) {
        return _start;
    }

    function end() external view returns(uint256) {
        return _end;
    }

    function unlockTime() external view returns(uint256) {
        return _unlockTime;
    }

    function isWhitelisted() external view returns(bool) {
        return _whitelist != address(0);
    }

    function launched() external view returns(bool) {
        return _launched;
    }

    function canceled() external view returns(bool) {
        return _canceled;
    }

    /**
     * @notice Withdraws BNB from the contract
     */
    function emergencyWithdrawBNB() payable external {
        require(_owner == msg.sender, "Only owner");
        payable(_owner).transfer(address(this).balance);
    }

    /**
     * @notice Withdraws non-RAINBOW tokens that are stuck as to not interfere with the liquidity
     */
    function emergencyWithdrawTokens(address token) payable external {
        require(_owner == msg.sender, "Only owner");
        IERC20(address(token)).transfer(_owner, IERC20(token).balanceOf(address(this)));
    }
}