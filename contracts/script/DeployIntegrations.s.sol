// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/integrations/BasePayDrip.sol";
import "../src/integrations/PaymentLinkFactory.sol";
import "../src/integrations/FiatQuoter.sol";
import "../src/PaymentStreamProxy.sol";

contract DeployIntegrations is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get existing PayDrip proxy address
        address payDripProxy = vm.envAddress("PAYDRIP_PROXY");

        // Oracle and Base Pay processor addresses
        // Default to deployer address if not set (recommended for MVP)
        address deployer = vm.addr(deployerPrivateKey);
        address oracle = vm.envOr("ORACLE_ADDRESS", deployer);
        address basePayProcessor = vm.envOr("BASEPAY_PROCESSOR", deployer);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Base Pay Integration contracts...");
        console.log("PayDrip Proxy:", payDripProxy);
        console.log("Oracle:", oracle);
        console.log("Base Pay Processor:", basePayProcessor);
        console.log("---");

        // 1. Deploy BasePayDrip
        console.log("Deploying BasePayDrip...");
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
        console.log("---");

        // 2. Deploy FiatQuoter
        console.log("Deploying FiatQuoter...");
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
        console.log("---");

        // 3. Deploy PaymentLinkFactory
        console.log("Deploying PaymentLinkFactory...");
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
        console.log("---");

        // Initialize FiatQuoter with default rate (1:1 for USDC)
        console.log("Setting initial USD rate (1:1)...");
        FiatQuoter fiatQuoter = FiatQuoter(address(fiatQuoterProxy));
        fiatQuoter.updateRate("USD", 1_000000); // 1 USD = 1 USDC
        console.log("USD rate set to 1:1");

        vm.stopBroadcast();

        console.log("\n==============================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("==============================================");
        console.log("BasePayDrip:", address(basePayDripProxy));
        console.log("PaymentLinkFactory:", address(linkFactoryProxy));
        console.log("FiatQuoter:", address(fiatQuoterProxy));
        console.log("==============================================\n");

        // Save deployment info
        string memory network = vm.envOr("NETWORK", string("unknown"));
        _saveDeployment(
            network,
            address(basePayDripProxy),
            address(linkFactoryProxy),
            address(fiatQuoterProxy)
        );
    }

    function _saveDeployment(
        string memory network,
        address basePayDrip,
        address linkFactory,
        address fiatQuoter
    ) internal {
        string memory json = string(
            abi.encodePacked(
                '{\n',
                '  "network": "', network, '",\n',
                '  "timestamp": "', vm.toString(block.timestamp), '",\n',
                '  "contracts": {\n',
                '    "BasePayDrip": "', vm.toString(basePayDrip), '",\n',
                '    "PaymentLinkFactory": "', vm.toString(linkFactory), '",\n',
                '    "FiatQuoter": "', vm.toString(fiatQuoter), '"\n',
                '  }\n',
                '}\n'
            )
        );

        string memory file = string(
            abi.encodePacked("deployments/integrations-", network, ".json")
        );

        vm.writeFile(file, json);
        console.log("Deployment info saved to:", file);
    }
}
