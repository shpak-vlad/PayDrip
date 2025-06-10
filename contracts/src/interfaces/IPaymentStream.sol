// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IPaymentStream {
    struct StreamInfo {
        address sender;
        address recipient;
        address token;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 withdrawn;
        bool active;
    }

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    );

    event Withdrawal(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );

    event StreamCancelled(
        uint256 indexed streamId,
        uint256 senderBalance,
        uint256 recipientBalance
    );

    function createStream(
        address recipient,
        address token,
        uint256 amount,
        uint256 duration
    ) external returns (uint256 streamId);

    function withdraw(uint256 streamId) external returns (uint256);

    function cancelStream(uint256 streamId) external;

    function getStream(uint256 streamId) external view returns (StreamInfo memory);

    function calculateWithdrawable(uint256 streamId) external view returns (uint256);
}
