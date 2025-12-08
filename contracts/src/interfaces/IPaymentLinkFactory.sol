// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IPaymentLinkFactory
 * @notice Interface for PaymentLinkFactory contract
 */
interface IPaymentLinkFactory {
    struct PaymentLink {
        bytes32 linkId;
        address creator;
        address receiver;
        uint256 amountPerStep;
        uint256 totalSteps;
        uint256 interval;
        uint256 expiry;
        bool used;
        bool multiUse;
        string memo;
        address token;
        uint256 createdAt;
        uint256 usageCount;
    }

    event LinkCreated(
        bytes32 indexed linkId,
        address indexed creator,
        address indexed receiver,
        uint256 totalAmount,
        uint256 expiry,
        bool multiUse
    );

    event LinkUsed(
        bytes32 indexed linkId,
        address indexed payer,
        uint256 indexed dripId,
        bool viaFiat
    );

    event LinkCancelled(
        bytes32 indexed linkId,
        address indexed creator
    );

    function createPaymentLink(
        address receiver,
        uint256 amountPerStep,
        uint256 totalSteps,
        uint256 interval,
        uint256 expiry,
        string calldata memo,
        address token,
        bool multiUse
    ) external returns (bytes32 linkId);

    function payViaLink(bytes32 linkId) external returns (uint256 dripId);

    function payViaLinkWithFiat(bytes32 linkId, string calldata returnUrl)
        external
        returns (bytes32 paymentId, string memory checkoutUrl);

    function cancelLink(bytes32 linkId) external;

    function getLinkInfo(bytes32 linkId) external view returns (PaymentLink memory);

    function isLinkValid(bytes32 linkId) external view returns (bool);

    function getUserLinks(address user) external view returns (bytes32[] memory);

    function getLinkDrips(bytes32 linkId) external view returns (uint256[] memory);
}
