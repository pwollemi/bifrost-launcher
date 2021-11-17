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
import 'contracts/uniswap/TransferHelper.sol';

import 'contracts/bifrost/IBifrostRouter01.sol';
import 'contracts/bifrost/IBifrostSale01.sol';
import 'contracts/bifrost/BifrostLauncher.sol';

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
    BifrostLauncher public  _launcher;      // The launching contract

    /**
     * @notice State Settings
     */
    bool public _prepared;   // True when the sale has been prepared to start by the owner
    bool public _launched;   // Whether the sale has been finalized and launched

    /**
     * @notice Checks if the caller is the Bifrost owner, Sale owner or the router itself
     */
    modifier isAdmin {
        require(_routerAddress == msg.sender || _owner == msg.sender || _runner == msg.sender, "Caller isnt an admin");
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
    uint256   public _unlockTime;    // The timestamp for when the liquidity lock should end

    /**
     * @notice TODO: SETTINGS TO IMPLEMENT
     */
    bool      public                  _useWhitelist;   // Whether the presale is public or private
    address[] private                 _whitelist;      // Addresses that are able to partake in the sale (unused if useWhitelist is false)
    mapping (address => bool) private _isWhitelisted;  // Whether or not an address is able to partake
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

        // Creates a launcher
        _launcher = new BifrostLauncher(address(this), runner, token, unlockTime);
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
        uint256 endTime
    ) external {
        _softCap = soft;
        _hardCap = hard;
        _min = min;
        _max = max;
        _presaleRate = presaleRate;
        _listingRate = listingRate;
        _liquidity = liquidity;
        _start = startTime;
        _end = endTime;

        _saleAmount      = _presaleRate.mul(_hardCap);
        _liquidityAmount = _listingRate.mul(_hardCap).mul(_liquidity).div(1e4);
        _totalTokens = _saleAmount.add(_liquidityAmount);
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

    /**
     * @notice Returns the address of the Sale owner.
     */
    function getRunner() override public view returns (address) {
        return _runner;
    }
    
    function setRunner(address runner) override external isAdmin {
        _runner = runner;
    }

    function canStart() override public view returns(bool) {
        return IERC20(_token).balanceOf(address(this)) >= _totalTokens;
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
        require(successful() || block.timestamp > _end, "Cannot finalize sale yet!");

        uint256 liquidityTokens = _liquidityAmount.mul(_liquidity).div(1e4);
        uint256 liquidityBNB = _raised.mul(_liquidity).div(1e4);
        TransferHelper.safeApprove(_token, address(_launcher), liquidityTokens);
        _launcher.launch{value:liquidityBNB}(liquidityTokens);

        TransferHelper.safeTransferETH(msg.sender, _raised.sub(liquidityBNB));
        TransferHelper.safeTransfer(_token, msg.sender, _liquidityAmount.sub(liquidityTokens));
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
            uint256 tokens = amount.mul(_presaleRate);
            TransferHelper.safeTransfer(_token, msg.sender, tokens);
        } else {
            // Otherwise return the user their BNB
            payable(msg.sender).transfer(amount);
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
        if (running()) {
            _deposited[user] = amount;
            _raised = _raised.add(amount);
        } else {
            _routerAddress.transfer(amount);
        }
    }
}