// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IWhitelist {
    function getUser(address _user)
        external
        view
        returns (
            address,
            uint256
        );
}
