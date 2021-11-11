
pragma solidity ^0.8.4;

import 'contracts/openzeppelin/Address.sol';
import 'contracts/openzeppelin/Context.sol';
import 'contracts/openzeppelin/Ownable.sol';
import 'contracts/openzeppelin/SafeMath.sol';
import 'contracts/openzeppelin/IERC20.sol';
import 'contracts/test/TestRouter.sol';
import 'hardhat/console.sol';

contract TestSale is Context, Ownable {

    address payable _router;

    bool public running;

    constructor (address payable router) {
        _router = router;
        running = true;
    }

    receive() external payable {
        _router.transfer(msg.value);
    }
}