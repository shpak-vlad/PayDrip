// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/StreamFactory.sol";

contract DeployFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        StreamFactory factory = new StreamFactory();
        console.log("StreamFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
