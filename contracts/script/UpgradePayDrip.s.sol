// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/PayDrip.sol";
import "../src/integrations/BasePayDrip.sol";
import "../src/integrations/PaymentLinkFactory.sol";
import "../src/integrations/FiatQuoter.sol";
import "../src/PaymentStreamProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UpgradePayDrip
 * @notice Comprehensive upgrade script that:
 *         1. Upgrades PayDrip proxy to new implementation
 *         2. Deploys Base Pay integration contracts
 *         3. Saves deployment info for verification
 */
contract UpgradePayDrip is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payDripProxy = vm.envAddress("PAYDRIP_PROXY");

        // Oracle and Base Pay processor addresses
        // Default to deployer address if not set (recommended for MVP)
        address deployer = vm.addr(deployerPrivateKey);
        address oracle = vm.envOr("ORACLE_ADDRESS", deployer);
        address basePayProcessor = vm.envOr("BASEPAY_PROCESSOR", deployer);

        vm.startBroadcast(deployerPrivateKey);

        console.log("\n==============================================");
        console.log("PAYDRIP UPGRADE & INTEGRATION DEPLOYMENT");
        console.log("==============================================");
        console.log("PayDrip Proxy:", payDripProxy);
        console.log("Oracle:", oracle);
        console.log("Base Pay Processor:", basePayProcessor);
        console.log("==============================================\n");

        // STEP 1: Upgrade PayDrip
        console.log("STEP 1: Upgrading PayDrip...");
        console.log("---");

        PayDrip newImplementation = new PayDrip();
        console.log("New PayDrip implementation:", address(newImplementation));

        PayDrip proxy = PayDrip(payDripProxy);
        proxy.upgradeToAndCall(address(newImplementation), "");
        console.log("✓ PayDrip proxy upgraded");

        // Verify upgrade
        bytes32 IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 implSlot = vm.load(payDripProxy, IMPLEMENTATION_SLOT);
        address currentImpl = address(uint160(uint256(implSlot)));
        require(currentImpl == address(newImplementation), "PayDrip upgrade failed!");
        console.log("✓ Upgrade verified\n");

        // STEP 2: Deploy BasePayDrip
        console.log("STEP 2: Deploying BasePayDrip...");
        console.log("---");

        BasePayDrip basePayDripImpl = new BasePayDrip();
        console.log("BasePayDrip implementation:", address(basePayDripImpl));

        bytes memory basePayDripInitData = abi.encodeWithSelector(
            BasePayDrip.initialize.selector,
            payDripProxy,
            oracle,
            basePayProcessor
        );

        PaymentStreamProxy basePayDripProxy = new PaymentStreamProxy(
            address(basePayDripImpl),
            basePayDripInitData
        );
        console.log("BasePayDrip proxy:", address(basePayDripProxy));
        console.log("✓ BasePayDrip deployed\n");

        // STEP 3: Deploy FiatQuoter
        console.log("STEP 3: Deploying FiatQuoter...");
        console.log("---");

        FiatQuoter fiatQuoterImpl = new FiatQuoter();
        console.log("FiatQuoter implementation:", address(fiatQuoterImpl));

        bytes memory fiatQuoterInitData = abi.encodeWithSelector(
            FiatQuoter.initialize.selector,
            oracle
        );

        PaymentStreamProxy fiatQuoterProxy = new PaymentStreamProxy(
            address(fiatQuoterImpl),
            fiatQuoterInitData
        );
        console.log("FiatQuoter proxy:", address(fiatQuoterProxy));

        // Initialize FiatQuoter with default rates
        FiatQuoter fiatQuoter = FiatQuoter(address(fiatQuoterProxy));
        fiatQuoter.updateRate("USD", 1_000000); // 1 USD = 1 USDC (6 decimals)
        console.log("✓ FiatQuoter deployed & initialized\n");

        // STEP 4: Deploy PaymentLinkFactory
        console.log("STEP 4: Deploying PaymentLinkFactory...");
        console.log("---");

        PaymentLinkFactory linkFactoryImpl = new PaymentLinkFactory();
        console.log("PaymentLinkFactory implementation:", address(linkFactoryImpl));

        bytes memory linkFactoryInitData = abi.encodeWithSelector(
            PaymentLinkFactory.initialize.selector,
            payDripProxy,
            address(basePayDripProxy)
        );

        PaymentStreamProxy linkFactoryProxy = new PaymentStreamProxy(
            address(linkFactoryImpl),
            linkFactoryInitData
        );
        console.log("PaymentLinkFactory proxy:", address(linkFactoryProxy));
        console.log("✓ PaymentLinkFactory deployed\n");

        vm.stopBroadcast();

        // Print summary
        console.log("==============================================");
        console.log("UPGRADE & DEPLOYMENT COMPLETE");
        console.log("==============================================");
        console.log("\nCore Contract:");
        console.log("  PayDrip (upgraded):", payDripProxy);
        console.log("  New implementation:", address(newImplementation));
        console.log("\nIntegration Contracts:");
        console.log("  BasePayDrip:", address(basePayDripProxy));
        console.log("  PaymentLinkFactory:", address(linkFactoryProxy));
        console.log("  FiatQuoter:", address(fiatQuoterProxy));
        console.log("\nConfiguration:");
        console.log("  Oracle:", oracle);
        console.log("  Base Pay Processor:", basePayProcessor);
        console.log("==============================================\n");

        // Save deployment info
        string memory network = vm.envOr("NETWORK", string("unknown"));
        _saveDeployment(
            network,
            payDripProxy,
            address(newImplementation),
            address(basePayDripProxy),
            address(linkFactoryProxy),
            address(fiatQuoterProxy),
            oracle,
            basePayProcessor
        );
    }

    function _saveDeployment(
        string memory network,
        address payDripProxy,
        address payDripImpl,
        address basePayDrip,
        address linkFactory,
        address fiatQuoter,
        address oracle,
        address basePayProcessor
    ) internal {
        string memory json = string(
            abi.encodePacked(
                '{\n',
                '  "network": "', network, '",\n',
                '  "timestamp": "', vm.toString(block.timestamp), '",\n',
                '  "upgrade": {\n',
                '    "payDripProxy": "', vm.toString(payDripProxy), '",\n',
                '    "newImplementation": "', vm.toString(payDripImpl), '"\n',
                '  },\n',
                '  "integrations": {\n',
                '    "BasePayDrip": "', vm.toString(basePayDrip), '",\n',
                '    "PaymentLinkFactory": "', vm.toString(linkFactory), '",\n',
                '    "FiatQuoter": "', vm.toString(fiatQuoter), '"\n',
                '  },\n',
                '  "configuration": {\n',
                '    "oracle": "', vm.toString(oracle), '",\n',
                '    "basePayProcessor": "', vm.toString(basePayProcessor), '"\n',
                '  }\n',
                '}\n'
            )
        );

        string memory file = string(
            abi.encodePacked("deployments/upgrade-", network, "-", vm.toString(block.timestamp), ".json")
        );

        vm.writeFile(file, json);
        console.log("Deployment info saved to:", file);
    }
}
