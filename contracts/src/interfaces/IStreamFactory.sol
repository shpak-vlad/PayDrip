// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IStreamFactory {
    event StreamContractDeployed(address indexed proxy, address indexed owner);
    
    function deployStream() external returns (address);
}
