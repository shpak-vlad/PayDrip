// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./PaymentStream.sol";
import "./PaymentStreamProxy.sol";

contract StreamFactory {
    event StreamContractDeployed(address indexed proxy, address indexed owner);

    function deployStream() external returns (address) {
        PaymentStream implementation = new PaymentStream();
        
        bytes memory initData = abi.encodeWithSelector(
            PaymentStream.initialize.selector
        );
        
        PaymentStreamProxy proxy = new PaymentStreamProxy(
            address(implementation),
            initData
        );
        
        PaymentStream(address(proxy)).transferOwnership(msg.sender);
        
        emit StreamContractDeployed(address(proxy), msg.sender);
        
        return address(proxy);
    }
}
