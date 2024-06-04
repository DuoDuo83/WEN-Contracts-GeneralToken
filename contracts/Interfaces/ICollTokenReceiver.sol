// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface ICollTokenReceiver {
    function onReceive(address _collToken, uint _amount) external;
}