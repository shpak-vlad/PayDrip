// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/PayDrip.sol";
import "../src/PaymentStreamProxy.sol";

contract DeployPayDrip is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        PayDrip implementation = new PayDrip();
        console.log("PayDrip implementation:", address(implementation));

        bytes memory initData = abi.encodeWithSelector(
            PayDrip.initialize.selector
        );

        PaymentStreamProxy proxy = new PaymentStreamProxy(
            address(implementation),
            initData
        );
        console.log("PayDrip proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
