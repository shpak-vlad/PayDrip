// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/PaymentStream.sol";
import "../src/PaymentStreamV2.sol";
import "../src/PaymentStreamProxy.sol";

contract UpgradeTest is Test {
    PaymentStream public v1;
    PaymentStreamV2 public v2;
    PaymentStreamProxy public proxy;

    function setUp() public {
        v1 = new PaymentStream();
        bytes memory initData = abi.encodeWithSelector(PaymentStream.initialize.selector);
        proxy = new PaymentStreamProxy(address(v1), initData);
    }

    function testUpgradeToV2() public {
        v2 = new PaymentStreamV2();
        PaymentStreamV2(address(proxy)).upgradeToAndCall(address(v2), "");
        
        assertTrue(address(proxy) != address(0));
    }

    function testStatePreservationAfterUpgrade() public {
        PaymentStream(address(proxy)).setPlatformFee(100);
        
        v2 = new PaymentStreamV2();
        PaymentStreamV2(address(proxy)).upgradeToAndCall(address(v2), "");
        
        assertEq(PaymentStreamV2(address(proxy)).platformFee(), 100);
    }
}
