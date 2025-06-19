// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library StreamLibrary {
    struct StreamData {
        address sender;
        address recipient;
        address token;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 withdrawn;
        bool active;
    }

    enum StreamStatus {
        Pending,
        Active,
        Completed,
        Cancelled
    }

    function calculateStreamedAmount(
        StreamData memory stream,
        uint256 currentTime
    ) internal pure returns (uint256) {
        if (currentTime <= stream.startTime) {
            return 0;
        }
        
        if (currentTime >= stream.endTime) {
            return stream.amount;
        }
        
        uint256 elapsed = currentTime - stream.startTime;
        uint256 duration = stream.endTime - stream.startTime;
        
        return (stream.amount * elapsed) / duration;
    }

    function calculateWithdrawableAmount(
        StreamData memory stream,
        uint256 currentTime
    ) internal pure returns (uint256) {
        uint256 streamed = calculateStreamedAmount(stream, currentTime);
        return streamed > stream.withdrawn ? streamed - stream.withdrawn : 0;
    }

    function getStreamStatus(
        StreamData memory stream,
        uint256 currentTime
    ) internal pure returns (StreamStatus) {
        if (!stream.active) {
            return StreamStatus.Cancelled;
        }
        
        if (currentTime < stream.startTime) {
            return StreamStatus.Pending;
        }
        
        if (currentTime >= stream.endTime || stream.withdrawn >= stream.amount) {
            return StreamStatus.Completed;
        }
        
        return StreamStatus.Active;
    }

    function validateStream(StreamData memory stream) internal pure returns (bool) {
        return stream.recipient != address(0) 
            && stream.token != address(0)
            && stream.amount > 0
            && stream.endTime > stream.startTime;
    }
}
