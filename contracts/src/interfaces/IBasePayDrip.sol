// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IBasePayDrip
 * @notice Interface for BasePayDrip integration contract
 */
interface IBasePayDrip {
    enum PaymentStatus {
        Pending,
        Confirmed,
        Failed,
        Refunded
    }

    struct PendingDrip {
        address sender;
        address receiver;
        address token;
        uint256 amountPerStep;
        uint256 totalSteps;
        uint256 interval;
        bytes32 paymentId;
        PaymentStatus status;
        uint256 createdAt;
        uint256 dripId;
    }

    event DripPaymentInitiated(
        bytes32 indexed paymentId,
        address indexed sender,
        address indexed receiver,
        uint256 totalAmount,
        string checkoutUrl
    );

    event DripPaymentConfirmed(
        bytes32 indexed paymentId,
        uint256 indexed dripId
    );

    event DripPaymentFailed(
        bytes32 indexed paymentId,
        string reason
    );

    event DripPaymentRefunded(
        bytes32 indexed paymentId,
        address indexed user,
        uint256 amount
    );

    function initiateDripWithFiat(
        address receiver,
        uint256 amountPerStep,
        uint256 totalSteps,
        uint256 interval,
        string calldata returnUrl
    ) external returns (bytes32 paymentId, string memory checkoutUrl);

    function confirmPayment(bytes32 paymentId, address token) external;

    function failPayment(bytes32 paymentId, string calldata reason) external;

    function finalizeDrip(bytes32 paymentId) external returns (uint256 dripId);

    function getPendingDrip(bytes32 paymentId) external view returns (PendingDrip memory);

    function getUserPendingDrips(address user) external view returns (bytes32[] memory);
}
