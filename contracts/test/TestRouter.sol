
pragma solidity ^0.8.4;

import 'contracts/openzeppelin-contracts/Address.sol';
import 'contracts/openzeppelin-contracts/Context.sol';
import 'contracts/openzeppelin-contracts/Ownable.sol';
import 'contracts/openzeppelin-contracts/SafeMath.sol';
import 'contracts/openzeppelin-contracts/IERC20.sol';
import 'hardhat/console.sol';

contract TestRouter is Context, Ownable {

    constructor () {}

    receive() external payable {
        
    }
}