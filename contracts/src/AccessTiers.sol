// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract AccessTiers {
    enum Tier { Basic, Premium, Enterprise }
    
    mapping(address => Tier) public userTiers;
    
    function setTier(address user, Tier tier) external {
        userTiers[user] = tier;
    }
}
