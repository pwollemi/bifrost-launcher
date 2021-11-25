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
import 'contracts/bifrost/BifrostSale01.sol';
import 'contracts/bifrost/Whitelist.sol';
import 'contracts/chainlink/AggregatorV3Interface.sol';
import 'contracts/pancakeswap/IPancakePair.sol';
import 'contracts/pancakeswap/IPancakeFactory.sol';
import "hardhat/console.sol";

/**
 * @notice The official Bifrost smart contract
 */
contract BifrostRouter01 is IBifrostRouter01, Context, Ownable {
    using SafeMath for uint256;
    using Address for address;

    address public constant RAINBOW = 0x673Da443da2f6aE7c5c660A9F0D3DD24d1643D36;
    IPancakeRouter02 public _pancakeswapV2Router;   // The address of the router

    uint256 private _id;                           // Increments for each sale that launches
    
    mapping (uint256 => address) public _ids;      // A mapping of sale IDs to owner addresses for O(1) retrieval
    mapping (address => Sale)    public _sales;    // A mapping of sale owners to the sales
    Sale[] public                       _saleList; // A list of sales

    mapping (address => bool) public _partnerTokens; // A mapping of token contract addresses to a flag describing whether or not they can be used to pay a fee
    mapping (address => bool) public _feePaid;       // A mapping of wallet addresses to a flag for whether they paid the fee via a partner token or not

    mapping (address => address) public _aggregators;  // token => price feed of BNB, can be chainlink aggregator with BNB

    uint256 public constant _totalPercentage = 10000; 
    uint256 public _partnerDiscount = 2000;  // Discount given for partner tokens 20%
    uint256 public _rainbowDiscount = 2500;  // Discount given for RAINBOW 25% 

    /**
     * @notice Stats
     */
    uint256 _totalRaised;          // Total amount of BNB raised
    uint256 _totalProjects;        // Total amount of launched projects
    uint256 _totalParticipants;    // Total amount of people partcipating
    uint256 _totalLiquidityLocked; // Total liquidity locked
    uint256 _savedInDiscounts;     // How much has been saved in discounts

    /**
     * @notice Sale Settings - these settings are used to ensure the configuration is compliant with what is fair for developers and users
     */
    uint256 public _listingFee;             // The flat fee in BNB
    uint256 public _launchingFee;           // The percentage fee for raised funds (only applicable for successful sales)
    uint256 public _minLiquidityPercentage; // The minimum liquidity percentage (5000 = 50%)
    uint256 public _minCapRatio;            // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
    uint256 public _minUnlockTimeSeconds;   // The minimum amount of time in seconds before liquidity can be unlocked
    uint256 public _minSaleTime;            // The minimum amount of time in seconds a sale has to run for
    uint256 public _maxSaleTime;            // If set, the maximum amount of time a sale has to run for

    /**
     * @notice A struct decribing a sale
     */
    struct Sale {
        address        runner;         // The person running the sale
        bool           created;        // Whether there is a sale created at this 
        uint256        id;             // The ID of the sale on the network this Router was deployed on
        BifrostSale01  saleContract;   // The address of the sale contract
    }

    /**
     * @notice The constructor for the router
     */
    constructor () {
        _id = 0;

        _listingFee             = 1e17;    // The flat fee in BNB (1e17 = 0.1 BNB)
        _launchingFee           = 100;     // The percentage of fees returned to the router owner for successful sales (100 = 1%)
        _minLiquidityPercentage = 5000;    // The minimum liquidity percentage (5000 = 50%)
        _minCapRatio            = 5000;    // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
        _minUnlockTimeSeconds   = 30 days; // The minimum amount of time before liquidity can be unlocked
        _minSaleTime            = 1 hours; // The minimum amount of time a sale has to run for
        _maxSaleTime            = 0; 

        _pancakeswapV2Router = IPancakeRouter02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); //0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3  0x10ED43C718714eb63d5aA57B78B54704E256024E
    }
    
    /**
     * @notice Forward all received BNB to the owner of the Bifrost Router
     */
    receive() external payable {
    }

    /**
     * @notice Withdraws BNB from the contract
     */
    function withdrawBNB(uint256 amount) override public onlyOwner {
        if(amount == 0) payable(owner()).transfer(address(this).balance);
        else payable(owner()).transfer(amount);
    }

    /**
     * @notice Withdraws non-RAINBOW tokens that are stuck as to not interfere with the liquidity
     */
    function withdrawForeignToken(address token) override external onlyOwner {
        IERC20(address(token)).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    /**
     * @notice Sets a token as able to decide fees of Bifrost
     */
    function setPartnerToken(address token, bool b) override external onlyOwner {
        _partnerTokens[token] = b;
    }

    /**
     * @notice Sets a token price feed of chainlink
     */
    function setPriceFeed(address token, address feed) override external onlyOwner {
        _aggregators[token] = feed;
    }

    /**
     * @notice Sets a token price feed
     */
    function listingFeeInToken(address token) public view returns (uint256) {
        uint256 bnbAmountOfOneToken = type(uint256).max;
        uint256 decimals = 18; // price decimals

        if (_aggregators[token] != address(0)) { // if chainlink aggregator is set
            AggregatorV3Interface aggregator = AggregatorV3Interface(_aggregators[token]);
            (, int256 answer, , , ) = aggregator.latestRoundData();
            require(answer > 0, "Invalid price feed");
            decimals = aggregator.decimals();
            bnbAmountOfOneToken = uint256(answer);
        } else { // use pancake pair
            IPancakePair pair = IPancakePair(IPancakeFactory(_pancakeswapV2Router.factory()).getPair(token, _pancakeswapV2Router.WETH()));
            address token0 = pair.token0();
            address token1 = pair.token1();
            uint256 decimals0 = IERC20(token0).decimals();
            uint256 decimals1 = IERC20(token1).decimals();

            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            // avoid mul and div by 0
            if (reserve0 > 0 && reserve1 > 0) {
                if (token == token0) {
                    bnbAmountOfOneToken = (10**(decimals + decimals0 - decimals1) * uint256(reserve1)) / uint256(reserve0);
                } else {
                    bnbAmountOfOneToken = (10**(decimals + decimals1 - decimals0) * uint256(reserve0)) / uint256(reserve1);
                }
            }
        }
        return _listingFee * (10 ** decimals) / uint256(bnbAmountOfOneToken);
    }

    /**
     * @notice Marks the sender as 
     */
    function payFee(address token) override external {
        uint256 discount = _partnerDiscount;
        if (token == RAINBOW) {
            discount = _rainbowDiscount;
        } else {
            require(_partnerTokens[token], "Token not a partner token!");
        }

        // Gets the fee in tokens, then takes a percentage discount to incentivize people paying in
        // tokens.
        uint256 feeInToken = listingFeeInToken(token);
        uint256 discountedFee = feeInToken.mul(_totalPercentage.sub(discount)).div(_totalPercentage);
        TransferHelper.safeTransferFrom(token, msg.sender, owner(), discountedFee);
        _feePaid[msg.sender] = true;

        _savedInDiscounts = _savedInDiscounts.add(feeInToken.sub(discountedFee));
    }

    /**
     * @notice Returns how many sale ids there are
     */
    function length() override external view returns(uint256) {
        return _id;
    }

    /**
     * @notice Validates the config of a sale lines up with the router settings 
     */
    function validate(
        uint256 soft, 
        uint256 hard, 
        uint256 liquidity, 
        uint256 start, 
        uint256 end, 
        uint256 unlockTime
    ) override public view {
        require(liquidity >= minimumLiquidityPercentage(), "Liquidity percentage below minimum");
        require(soft.mul(1e5).div(hard).div(10) >= capRatio(), "Soft cap too low compared to hard cap");
        require(end.sub(start).add(1) >= minimumSaleTime(), "Sale time too short");
        if (maximumSaleTime() > 0) {
            require(end.sub(start) < maximumSaleTime(), "Sale time too long");
        }
        require(unlockTime >= minimumUnlockTimeSeconds(), "Minimum unlock time is too low");
    }

    /**
     * @notice Called by anyone who wishes to begin their own token sale
     */
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
        uint256 unlockTime,
        bool isPublicSale
    ) override external payable {
        // Ensure the runner hasn't run a sale before
        require(!_sales[msg.sender].created, "This wallet is already managing a sale!");

        // Validates the sale config
        validate(soft, hard, liquidity, start, end, unlockTime);

        // If the person creating the sale hasn't paid the fee, then this call needs to pay the appropriate BNB. 
        if (!_feePaid[msg.sender]) {
            require(msg.value == listingFee(), "Not paying the listing fee");
            payable(owner()).transfer(msg.value);
        }

        BifrostSale01 newSale = new BifrostSale01(
            payable(address(this)), 
            owner(), 
            msg.sender, 
            token, 
            unlockTime
        );
        _sales[msg.sender] = Sale(msg.sender, true, _id, newSale);
        _ids[_id] = msg.sender;
        _id++;
        _saleList.push(_sales[msg.sender]);

        _configure( 
            soft, 
            hard, 
            min, 
            max, 
            presaleRate, 
            listingRate, 
            liquidity, 
            start, 
            end,
            isPublicSale
        );
        
        // Transfer via the Router to avoid taxing
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), newSale.totalTokens());
        //IERC20(token).transferFrom(msg.sender, address(this), newSale.totalTokens());

        // Incase tax wasn't disabled, transfer as many tokens as we can and ask the developer to
        // fix this with a top
        TransferHelper.safeTransfer(token, address(newSale), IERC20(token).balanceOf(address(this)));
        //IERC20(token).transfer(address(newSale), IERC20(token).balanceOf(address(this)));

    }

    function _configure(
        uint256 soft, 
        uint256 hard, 
        uint256 min, 
        uint256 max, 
        uint256 presaleRate, 
        uint256 listingRate, 
        uint256 liquidity, 
        uint256 start, 
        uint256 end,
        bool isPublicSale
    ) internal {
        _sales[msg.sender].saleContract.configure(
            soft, 
            hard, 
            min, 
            max, 
            presaleRate, 
            listingRate, 
            liquidity, 
            start, 
            end,
            isPublicSale
        );
    }

    /**
     * @notice Returns the sale of the caller
     */
    function getSale() external view returns(address, bool, uint256, address) {
        return (
            _sales[msg.sender].runner,
            _sales[msg.sender].created,
            _sales[msg.sender].id,
            address(_sales[msg.sender].saleContract)
        );
    }

    /**
     * @notice Returns the sale at a given ID
     */
    function getSaleByID(uint256 id) external view returns(Sale memory) {
        return _sales[_ids[id]];
    }
    
    /**
     * @notice Returns the sale of a given owner
     */
    function getSaleByOwner(address owner) external view returns(Sale memory) {
        return _sales[owner];
    }

    /**
     * @notice GETTERS AND SETTERS
     */
    function setPartnerDiscount(uint256 partnerDiscount) external onlyOwner {
        _partnerDiscount = partnerDiscount;
    }
    function partnerDiscount() public view returns (uint256) { return _partnerDiscount; }
    function setRainbowDiscount(uint256 rainbowDiscount) external onlyOwner {
        _rainbowDiscount = rainbowDiscount;
    }
    function rainbowDiscount() public view returns (uint256) { return _rainbowDiscount; }
    function setListingFee(uint256 listingFee) external onlyOwner {
        _listingFee = listingFee;
    }
    function listingFee() public view returns (uint256) { return _listingFee; }

    function setLaunchingFee(uint256 launchingFee) external onlyOwner {
        _launchingFee = launchingFee;
    }
    function launchingFee() public override view returns (uint256) {return _launchingFee;}

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

    function setMaximumSaleTime(uint256 maxSaleTime) external onlyOwner {
        _maxSaleTime = maxSaleTime;
    }
    function maximumSaleTime() public view returns (uint256) {return _maxSaleTime;}
}