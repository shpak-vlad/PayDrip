// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library DataTypes {
    struct CompactStream {
        address sender;
        address recipient;
        address token;
        uint96 amount;
        uint32 startTime;
        uint32 endTime;
        uint96 withdrawn;
        bool active;
        bool cancelled;
    }

    struct StreamMetadata {
        string description;
        bytes32 category;
        uint256 createdAt;
    }

    struct UserStats {
        uint128 totalSent;
        uint128 totalReceived;
        uint64 streamsAsSender;
        uint64 streamsAsRecipient;
        uint32 lastActivity;
    }

    function packAmount(uint256 amount) internal pure returns (uint96) {
        require(amount <= type(uint96).max, "Amount too large");
        return uint96(amount);
    }

    function packTimestamp(uint256 timestamp) internal pure returns (uint32) {
        require(timestamp <= type(uint32).max, "Timestamp overflow");
        return uint32(timestamp);
    }

    function unpackAmount(uint96 amount) internal pure returns (uint256) {
        return uint256(amount);
    }

    function unpackTimestamp(uint32 timestamp) internal pure returns (uint256) {
        return uint256(timestamp);
    }
}
