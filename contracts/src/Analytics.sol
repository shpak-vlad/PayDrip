// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract Analytics {
    struct Stats {
        uint256 totalVolume;
        uint256 activeStreams;
    }
    
    Stats public globalStats;
}
