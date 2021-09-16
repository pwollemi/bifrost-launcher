
pragma solidity ^0.8.4;

import 'contracts/openzeppelin-contracts/Address.sol';
import 'contracts/openzeppelin-contracts/Context.sol';
import 'contracts/openzeppelin-contracts/Ownable.sol';
import 'contracts/openzeppelin-contracts/SafeMath.sol';
import 'contracts/openzeppelin-contracts/IERC20.sol';
import 'contracts/test/TestRouter.sol';
import 'hardhat/console.sol';

contract TestSale is Context, Ownable {

    address payable _router;

    bool public running;

    constructor (address payable router) {
        _router = router;
        running = true;
    }

    function setRunning(bool b) external {
        running = b;
    }

    receive() external payable {
        if(!running) {
            _router.transfer(msg.value);
        }
    }
}