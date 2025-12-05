// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/PayDrip.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradePayDrip is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PAYDRIP_PROXY");

        vm.startBroadcast(deployerPrivateKey);

        console.log("Upgrading PayDrip at proxy:", proxyAddress);
        console.log("---");

        // Deploy new implementation
        console.log("Deploying new PayDrip implementation...");
        PayDrip newImplementation = new PayDrip();
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade the proxy
        console.log("Upgrading proxy to new implementation...");
        PayDrip proxy = PayDrip(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        console.log("Upgrade completed!");

        // Verify upgrade
        console.log("---");
        console.log("Verifying upgrade...");

        // Get implementation address from proxy
        bytes32 IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 implSlot = vm.load(proxyAddress, IMPLEMENTATION_SLOT);
        address currentImpl = address(uint160(uint256(implSlot)));

        console.log("Current implementation:", currentImpl);
        require(currentImpl == address(newImplementation), "Upgrade failed!");

        console.log("✓ Upgrade verified successfully");
        console.log("---");

        vm.stopBroadcast();

        // Save upgrade info
        string memory network = vm.envOr("NETWORK", string("unknown"));
        _saveUpgrade(network, proxyAddress, address(newImplementation));
    }

    function _saveUpgrade(
        string memory network,
        address proxy,
        address implementation
    ) internal {
        string memory json = string(
            abi.encodePacked(
                '{\n',
                '  "network": "', network, '",\n',
                '  "timestamp": "', vm.toString(block.timestamp), '",\n',
                '  "proxy": "', vm.toString(proxy), '",\n',
                '  "newImplementation": "', vm.toString(implementation), '"\n',
                '}\n'
            )
        );

        string memory file = string(
            abi.encodePacked("deployments/upgrade-", network, "-", vm.toString(block.timestamp), ".json")
        );

        vm.writeFile(file, json);
        console.log("Upgrade info saved to:", file);
    }
}
