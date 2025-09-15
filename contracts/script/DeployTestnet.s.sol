// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/PaymentStream.sol";
import "../src/PaymentStreamProxy.sol";

contract DeployTestnetScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        PaymentStream implementation = new PaymentStream();
        bytes memory initData = abi.encodeWithSelector(PaymentStream.initialize.selector);
        PaymentStreamProxy proxy = new PaymentStreamProxy(address(implementation), initData);
        
        console.log("Deployed to testnet at:", address(proxy));
        vm.stopBroadcast();
    }
}
