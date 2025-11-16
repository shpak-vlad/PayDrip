// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./PaymentStream.sol";

contract PaymentStreamV2 is PaymentStream {
    mapping(uint256 => bool) public streamPaused;
    mapping(uint256 => uint256) public streamRateMultiplier;
    
    uint256 public constant MULTIPLIER_DENOMINATOR = 10000;
    
    event StreamPausedEvent(uint256 indexed streamId);
    event StreamUnpausedEvent(uint256 indexed streamId);
    event RateMultiplierSet(uint256 indexed streamId, uint256 multiplier);

    function pauseStream(uint256 streamId) 
        external 
        streamExists(streamId)
        onlyStreamSender(streamId)
    {
        streamPaused[streamId] = true;
        emit StreamPausedEvent(streamId);
    }

    function unpauseStream(uint256 streamId)
        external
        streamExists(streamId)
        onlyStreamSender(streamId)
    {
        streamPaused[streamId] = false;
        emit StreamUnpausedEvent(streamId);
    }

    function setStreamRateMultiplier(uint256 streamId, uint256 multiplier)
        external
        streamExists(streamId)
        onlyStreamSender(streamId)
    {
        require(multiplier > 0 && multiplier <= 20000, "Invalid multiplier");
        streamRateMultiplier[streamId] = multiplier;
        emit RateMultiplierSet(streamId, multiplier);
    }

    function _calculateWithdrawable(uint256 streamId) internal view override returns (uint256) {
        if (streamPaused[streamId]) return 0;
        
        uint256 baseAmount = super._calculateWithdrawable(streamId);
        uint256 multiplier = streamRateMultiplier[streamId];
        
        if (multiplier > 0) {
            return (baseAmount * multiplier) / MULTIPLIER_DENOMINATOR;
        }
        
        return baseAmount;
    }
}
