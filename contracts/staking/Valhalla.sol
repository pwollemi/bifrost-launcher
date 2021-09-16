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

/**
 * @notice The official Valhalla staking/farming smart contract
 */
contract Freyr is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;

    bool public _active;

    /**
     * @notice Checks if the contract is active
     */
    modifier isActive {
        require(_active, "Error: Contract paused");
        _;
    }

    /**
     * @notice Checks if the msg.sender is a contract or a proxy
     */
    modifier notContract() {
        require(!isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    struct AccountInfo {
        uint256 shares;            // The number of shares of the pool this account has
        uint256 lastTimeDeposited; // Tracks the last time the account deposited funds
        uint256 lastTimeWithdrawn; // Tracks the last time the account withdrew funds
    }

    mapping(address => AccountInfo) public _accounts;

    address public _developer;
    address public _treasury;
    IERC20 public immutable _stakingToken; // RAINBOW
    IERC20 public immutable _earningToken; // PRISM

    uint256 public _totalShares;
    uint256 public _lastHarvestedTime;

    constructor (address stakeToken, address earnToken) {
        _active = false;
        _stakingToken = IERC20(stakeToken);
        _earningToken = IERC20(earnToken);
    }

    /**
     * @notice Required to recieve BNB from PancakeSwap V2 Router when swaping
     */
    receive() external payable {}

    function deposit(uint256 amount) external isActive notContract {

    }

    function withdraw(uint256 shares) public notContract {

    }

    /**
     * @notice Checks if address is a contract
     */
    function isContract(address _address) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_address) }
        return size > 0;
    }
}