// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";

abstract contract BaseTest is Test {
    uint256 internal constant INITIAL_BALANCE = 100 ether;
    
    function _dealETH(address account, uint256 amount) internal {
        vm.deal(account, amount);
    }
    
    function _skip(uint256 time) internal {
        vm.warp(block.timestamp + time);
    }
    
    function _expectRevertWith(bytes memory reason) internal {
        vm.expectRevert(reason);
    }
}
