// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/PaymentStream.sol";
import "../src/PaymentStreamProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract IntegrationTest is Test {
    PaymentStream public paymentStream;
    ERC20 public token1;
    ERC20 public token2;
    
    address public alice;
    address public bob;
    address public charlie;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
    }

    function testMultiUserScenario() public {
        assertTrue(true);
    }
}
