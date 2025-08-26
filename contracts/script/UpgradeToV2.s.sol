// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/PaymentStreamV2.sol";

contract UpgradeToV2Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        PaymentStreamV2 newImplementation = new PaymentStreamV2();
        console.log("V2 Implementation deployed at:", address(newImplementation));

        PaymentStreamV2 proxy = PaymentStreamV2(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        console.log("Proxy upgraded to V2");

        vm.stopBroadcast();
    }
}
// Additional upgrade utilities
