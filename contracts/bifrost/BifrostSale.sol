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

import 'contracts/bifrost/BifrostLauncher.sol';
import 'contracts/bifrost/BifrostRouter.sol';

/**
 * @notice A Bifrost Sale
 */
contract BifrostSale is Context {
    using SafeMath for uint256;
    using Address for address;

    BifrostRouter public _router;
    address payable public _routerAddress;    // The Bifrost router
    address public _owner;           // The person running the sale
    bool    public _configured;      // Whether the sale is ready to be started
    bool    public _running;         // Whether the sale is currently running or not
    bool    public _finished;        // Whether the sale has been finished 
    bool    public _successful;      // Whether the sale has been finished 
    bool    public _finalized;       // Whether the sale has been finalized (launched to PcS)

    /**
     * @notice Checks if the caller is the sale owner or the router
     */
    modifier isAdmin {
        require(_routerAddress == msg.sender || _router.owner() == msg.sender || _owner == msg.sender, "Caller isnt an admin");
        _;
    }

    /**
     * @notice Checks if the caller is the sale owner or the router
     */
    modifier isConfigured {
        require(_configured, "Sale hasnt been configured yet");
        _;
    }

    /**
     * @notice Checks if the sale is running
     */
    modifier isRunning {
        require(_running, "Sale isnt running");
        _;
    }

    /**
     * @notice Checks if the sale is finished
     */
    modifier isFinished {
        require(_finished, "Sale hasnt finished yet");
        _;
    }

    /**
     * @notice Checks if the sale has been finalized
     */
    modifier isFinalized {
        require(_finalized, "Sale hasnt been finalized yet");
        _;
    }

    /**
     * @notice Configuration
     */
    bool      public _useNative;     // Whether the to pair with the fundamental crypto coin 
    address   public _tokenA;        // The token that the sale is selling
    address   public _tokenB;        // The token that will be used if useNative is false
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
     * @notice Whitelist Settings
     */
    bool      public                  _useWhitelist;   // Whether the presale is public or private
    address[] private                 _whitelist;      // Addresses that are able to partake in the sale (unused if useWhitelist is false)
    mapping (address => bool) private _isWhitelisted;  // Whether or not an address is able to partake

    /**
     * @notice Current Status - These are modified after a sale has been setup and is running
     */
    uint256 public _aBalance;   // How many tokens are on sale
    uint256 public _aLiquidity; // How many tokens are allocated for liquidity
    uint256 public _bBalance;   // How much BNB/tokenB has been raised
    mapping(address => uint256) _deposited; // A mapping of addresses to an amount of raised token
    
    /**
     * @notice Creates a bifrost sale
     */
    constructor (address payable router, address owner, bool useWhitelist, bool useNative) {
        // Set the owner of the sale to be the owner of the deployer 
        _routerAddress = router;
        _router = BifrostRouter(router);
        _owner  = owner;

        _configured = false;
        _useWhitelist = useWhitelist;
        _useNative = useNative;
    }

    /**
     * @notice If the presale isn't running will direct any received payments straight to the router
     */
    receive() external payable {
        if (!_running) {
            _routerAddress.transfer(msg.value);
        } else if (is_running && !_useNative) {
            _deposited[msg.sender] = msg.value;
        }
    }
    
    /**
     * @notice Returns the address of the Sale owner.
     */
    function getOwner() public view returns (address) {
        return _owner;
    }
    
    function setOwner(address owner) external isAdmin {
        _owner = owner;
    }

    function setUseWhiteList(bool b) external isAdmin {
        _useWhitelist = b;
    }
    
    function setUseNative(bool b) external isAdmin {
        _useNative = b;
    }
    
    /**
     * @notice Setups a native token sale
     */
    function setupNative(address tokenA, uint256 softCap, uint256 hardCap, uint256 min, uint256 max, uint256 presaleRate, 
                        uint256 listingRate, uint256 liquidity, uint256 startTime, uint256 endTime, uint256 unlockTime) external isAdmin {
        require(_useNative, "You have to enable native sale to setup a native sale");
        _tokenA = tokenA;
        _tokenB = 0x0000000000000000000000000000000000000000;
        _softCap = softCap;
        _hardCap = hardCap;
        _min = min;
        _max = max;
        _presaleRate = presaleRate;
        _listingRate = listingRate;
        _liquidity = liquidity;
        _start = startTime;
        _end = endTime;
        _unlockTime = unlockTime;

        _setup();
    }
    
    /**
     * @notice Setups a token sale
     */
    function setup(address tokenA, address tokenB, uint256 softCap, uint256 hardCap, uint256 min, uint256 max, uint256 presaleRate, 
                        uint256 listingRate, uint256 liquidity, uint256 startTime, uint256 endTime, uint256 unlockTime) external isAdmin {
        require(!_useNative, "You have to disable native sale to setup a non-native sale");
        _tokenA = tokenA;
        _tokenB = tokenB;
        _softCap = softCap;
        _hardCap = hardCap;
        _min = min;
        _max = max;
        _presaleRate = presaleRate;
        _listingRate = listingRate;
        _liquidity = liquidity;
        _start = startTime;
        _end = endTime;
        _unlockTime = unlockTime;

        _setup();
    }

    /**
     * @notice Ensures that the sale is valid
     */
    function _setup() internal {
        require(_liquidity >= _router.minimumLiquidityPercentage(), "Liquidity percentage below minimum");
        uint256 ratio = _softCap.mul(1e5).div(_hardCap).div(10); // 5000 means 50%
        require(ratio >= _router.capRatio(), "Soft cap too low compared to hard cap");
        require(_router.minimumUnlockTime() >= _unlockTime, "Minimum unlock time is too low");
        uint256 saleTime = _end.sub(_start);
        require(saleTime >= _router.minimumSaleTime(), "Sale time too short");
        if (_router.maximumSaleTime() > 0) {
            require(saleTime < _router.maximumSaleTime(), "Sale time too long");
        }

        require(msg.value == _router.listingFee(), "Listing fee is wrong");

        uint256 aAmountPresale   = _presaleRate.mul(_hardCap);
        uint256 aAmountLiquidity = _listingRate.mul(_hardCap).mul(_liquidity);

        _configured = true;
    }
    
    /**
     * @notice Setups a token sale
     */
    function start(uint256 aAmount) external isAdmin isConfigured {
        
    }

    /**
     * @notice Finishes the sale, and if successful launches to PancakeSwap
     * @dev This entitles msg.sender to (amount * _presaleRate) after a successful sale
     */
    function finalize() external isAdmin isFinished {
        if (_bBalance >= _softCap) {
            _successful = true;

            uint256 amountTokenA = _aLiquidity.mul(_liquidity).div(1e4);
            uint256 amountTokenB = _bBalance.mul(_liquidity).div(1e4);

            BifrostLauncher launcher = new BifrostLauncher(_owner, _useNative, _tokenA, _tokenB, _unlockTime);
            launcher.launch(amountTokenA, amountTokenB);
        } else {
            _successful = false;
        }
    }

    /**
     * @notice For users to deposit into the sale
     * @dev This entitles msg.sender to (amount * _presaleRate) after a successful sale
     */
    function deposit(uint256 amount) external isRunning {

    }

    /**
     * @notice For users to withdraw from a sale
     * @dev This entitles msg.sender to (amount * _presaleRate) after a successful sale
     */
    function withdraw() external isFinished isFinalized {
        uint256 deposited = _deposited[msg.sender];
        uint256 tokens = deposited.mul(_presaleRate);
        if (deposited > 0) {
            if(_useNative) {
                payable(_router).transfer(tokens);
            } else {
                IERC20(_tokenB).transfer(msg.sender, tokens);
            }
        }
    }
}