// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

/**
 * @title GetAddress
 * @notice Helper script to get your address from private key
 */
contract GetAddress is Script {
    function run() external view {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address addr = vm.addr(privateKey);

        console.log("==============================================");
        console.log("Your Address:", addr);
        console.log("==============================================");
        console.log("");
        console.log("Add this to your .env file:");
        console.log("ORACLE_ADDRESS=%s", addr);
        console.log("BASEPAY_PROCESSOR=%s", addr);
        console.log("==============================================");
    }
}
