// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./PaymentStream.sol";

contract PaymentStreamV2 is PaymentStream {
    mapping(uint256 => bool) public streamPaused;
    
    event StreamPausedEvent(uint256 indexed streamId);
    event StreamUnpausedEvent(uint256 indexed streamId);

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

    function _calculateWithdrawable(uint256 streamId) internal view override returns (uint256) {
        if (streamPaused[streamId]) return 0;
        return super._calculateWithdrawable(streamId);
    }
}
