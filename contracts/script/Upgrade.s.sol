// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/PaymentStream.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        PaymentStream newImplementation = new PaymentStream();
        console.log("New implementation deployed at:", address(newImplementation));

        PaymentStream proxy = PaymentStream(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        console.log("Proxy upgraded successfully");

        vm.stopBroadcast();
    }
}
