// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/StreamCloner.sol";

contract StreamClonerTest is Test {
    StreamCloner public cloner;
    
    function setUp() public {
        cloner = new StreamCloner();
    }
    
    function testClone() public {
        uint256 clonedId = cloner.cloneStream(1);
        assertEq(clonedId, 1);
    }
}
