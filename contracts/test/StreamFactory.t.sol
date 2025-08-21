// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/StreamFactory.sol";
import "../src/PaymentStream.sol";

contract StreamFactoryTest is Test {
    StreamFactory public factory;

    function setUp() public {
        factory = new StreamFactory();
    }

    function testDeployStream() public {
        address streamAddress = factory.deployStream();
        assertTrue(streamAddress != address(0));
        
        PaymentStream stream = PaymentStream(streamAddress);
        assertEq(stream.owner(), address(this));
    }

    function testMultipleDeployments() public {
        address stream1 = factory.deployStream();
        address stream2 = factory.deployStream();
        
        assertTrue(stream1 != stream2);
    }
}
