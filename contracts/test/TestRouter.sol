
pragma solidity ^0.8.4;

import 'contracts/openzeppelin/Address.sol';
import 'contracts/openzeppelin/Context.sol';
import 'contracts/openzeppelin/Ownable.sol';
import 'contracts/openzeppelin/SafeMath.sol';
import 'contracts/openzeppelin/IERC20.sol';
import 'hardhat/console.sol';
import 'contracts/test/TestSale.sol';

contract TestRouter is Context, Ownable {

    mapping(address => TestSale) _sales;

    constructor () {}

    receive() external payable {
        
    }

    function createSale() payable external {
        require(msg.value >= 1e18, "Fee not paid!");
        payable(address(this)).send(msg.value);
        _sales[msg.sender] = new TestSale(payable(address(this)));
    }
}