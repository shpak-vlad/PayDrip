// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/PayDrip.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateTestDrips is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payDripProxy = vm.envAddress("PAYDRIP_PROXY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        PayDrip payDrip = PayDrip(payDripProxy);
        IERC20 token = IERC20(tokenAddress);

        address receiver1 = address(0x1111111111111111111111111111111111111111);
        address receiver2 = address(0x2222222222222222222222222222222222222222);
        address receiver3 = address(0x3333333333333333333333333333333333333333);

        uint256 amountPerStep = 10 * 10**6;
        uint256 totalSteps = 10;
        uint256 interval = 7 days;

        uint256 totalAmount = amountPerStep * totalSteps * 3;
        token.approve(payDripProxy, totalAmount);

        uint256 drip1 = payDrip.createDrip(
            amountPerStep,
            totalSteps,
            interval,
            receiver1,
            tokenAddress
        );
        console.log("Created drip 1:", drip1);

        uint256 drip2 = payDrip.createDrip(
            amountPerStep,
            totalSteps,
            interval,
            receiver2,
            tokenAddress
        );
        console.log("Created drip 2:", drip2);

        uint256 drip3 = payDrip.createDrip(
            amountPerStep,
            totalSteps,
            interval,
            receiver3,
            tokenAddress
        );
        console.log("Created drip 3:", drip3);

        vm.stopBroadcast();
    }
}
