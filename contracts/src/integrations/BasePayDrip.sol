// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPayDrip.sol";

/**
 * @title BasePayDrip
 * @notice Bridge between Base Pay fiat on-ramp and PayDrip drip creation
 * @dev Manages pending drips awaiting fiat payment confirmation
 */
contract BasePayDrip is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
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

    IPayDrip public payDrip;
    address public oracle;
    address public basePayProcessor;

    mapping(bytes32 => PendingDrip) public pendingDrips;
    mapping(address => bytes32[]) public userPendingDrips;
    mapping(bytes32 => bool) public processedPayments;

    uint256 public constant PAYMENT_TIMEOUT = 24 hours;
    uint256 public pendingDripCounter;

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

    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event BasePayProcessorUpdated(address indexed oldProcessor, address indexed newProcessor);

    error InvalidReceiver();
    error InvalidAmount();
    error InvalidSteps();
    error InvalidInterval();
    error InvalidToken();
    error PaymentNotFound();
    error PaymentAlreadyProcessed();
    error PaymentExpired();
    error Unauthorized();
    error InvalidStatus();

    modifier onlyOracle() {
        if (msg.sender != oracle) revert Unauthorized();
        _;
    }

    modifier onlyBasePayProcessor() {
        if (msg.sender != basePayProcessor) revert Unauthorized();
        _;
    }

    function initialize(
        address _payDrip,
        address _oracle,
        address _basePayProcessor
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        payDrip = IPayDrip(_payDrip);
        oracle = _oracle;
        basePayProcessor = _basePayProcessor;
        pendingDripCounter = 0;
    }

    /**
     * @notice Initiate a drip payment with fiat on-ramp
     * @param receiver Address to receive the drip payments
     * @param amountPerStep Amount per drip step
     * @param totalSteps Total number of steps
     * @param interval Time between steps in seconds
     * @param returnUrl URL to return after payment
     * @return paymentId Unique payment identifier
     * @return checkoutUrl Base Pay checkout URL
     */
    function initiateDripWithFiat(
        address receiver,
        uint256 amountPerStep,
        uint256 totalSteps,
        uint256 interval,
        string calldata returnUrl
    ) external returns (bytes32 paymentId, string memory checkoutUrl) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (receiver == msg.sender) revert InvalidReceiver();
        if (amountPerStep == 0) revert InvalidAmount();
        if (totalSteps == 0) revert InvalidSteps();
        if (interval == 0) revert InvalidInterval();

        paymentId = keccak256(
            abi.encodePacked(
                msg.sender,
                receiver,
                amountPerStep,
                totalSteps,
                block.timestamp,
                pendingDripCounter++
            )
        );

        uint256 totalAmount = amountPerStep * totalSteps;

        pendingDrips[paymentId] = PendingDrip({
            sender: msg.sender,
            receiver: receiver,
            token: address(0), // Will be set to USDC on confirmation
            amountPerStep: amountPerStep,
            totalSteps: totalSteps,
            interval: interval,
            paymentId: paymentId,
            status: PaymentStatus.Pending,
            createdAt: block.timestamp,
            dripId: 0
        });

        userPendingDrips[msg.sender].push(paymentId);

        // Generate checkout URL (in production, this would call Base Pay API)
        checkoutUrl = string(
            abi.encodePacked(
                "https://pay.base.org/checkout/",
                _bytes32ToString(paymentId),
                "?amount=",
                _uint2str(totalAmount),
                "&returnUrl=",
                returnUrl
            )
        );

        emit DripPaymentInitiated(
            paymentId,
            msg.sender,
            receiver,
            totalAmount,
            checkoutUrl
        );

        return (paymentId, checkoutUrl);
    }

    /**
     * @notice Confirm payment and set token address
     * @dev Called by oracle or Base Pay processor after fiat payment confirmation
     * @param paymentId Payment identifier
     * @param token Token address (USDC on Base)
     */
    function confirmPayment(bytes32 paymentId, address token)
        external
        onlyOracle
        nonReentrant
    {
        PendingDrip storage pending = pendingDrips[paymentId];

        if (pending.sender == address(0)) revert PaymentNotFound();
        if (processedPayments[paymentId]) revert PaymentAlreadyProcessed();
        if (pending.status != PaymentStatus.Pending) revert InvalidStatus();
        if (block.timestamp > pending.createdAt + PAYMENT_TIMEOUT) {
            revert PaymentExpired();
        }
        if (token == address(0)) revert InvalidToken();

        pending.status = PaymentStatus.Confirmed;
        pending.token = token;
        processedPayments[paymentId] = true;

        emit DripPaymentConfirmed(paymentId, 0);
    }

    /**
     * @notice Mark payment as failed
     * @dev Called by oracle or Base Pay processor if payment fails
     * @param paymentId Payment identifier
     * @param reason Failure reason
     */
    function failPayment(bytes32 paymentId, string calldata reason)
        external
        onlyOracle
    {
        PendingDrip storage pending = pendingDrips[paymentId];

        if (pending.sender == address(0)) revert PaymentNotFound();
        if (processedPayments[paymentId]) revert PaymentAlreadyProcessed();
        if (pending.status != PaymentStatus.Pending) revert InvalidStatus();

        pending.status = PaymentStatus.Failed;
        processedPayments[paymentId] = true;

        emit DripPaymentFailed(paymentId, reason);
    }

    /**
     * @notice Finalize drip creation after payment confirmation
     * @dev Creates actual drip in PayDrip contract
     * @param paymentId Payment identifier
     * @return dripId Created drip ID
     */
    function finalizeDrip(bytes32 paymentId)
        external
        nonReentrant
        returns (uint256 dripId)
    {
        PendingDrip storage pending = pendingDrips[paymentId];

        if (pending.sender == address(0)) revert PaymentNotFound();
        if (pending.status != PaymentStatus.Confirmed) revert InvalidStatus();
        if (pending.dripId != 0) revert PaymentAlreadyProcessed();

        uint256 totalAmount = pending.amountPerStep * pending.totalSteps;

        // Transfer tokens from this contract to PayDrip
        // In production, tokens would be received from Base Pay
        IERC20(pending.token).transferFrom(
            pending.sender,
            address(this),
            totalAmount
        );

        // Approve PayDrip to spend tokens
        IERC20(pending.token).approve(address(payDrip), totalAmount);

        // Create drip in PayDrip contract
        dripId = payDrip.createDrip(
            pending.amountPerStep,
            pending.totalSteps,
            pending.interval,
            pending.receiver,
            pending.token
        );

        pending.dripId = dripId;

        emit DripPaymentConfirmed(paymentId, dripId);

        return dripId;
    }

    /**
     * @notice Get pending drip details
     * @param paymentId Payment identifier
     * @return Pending drip details
     */
    function getPendingDrip(bytes32 paymentId)
        external
        view
        returns (PendingDrip memory)
    {
        return pendingDrips[paymentId];
    }

    /**
     * @notice Get all pending drips for a user
     * @param user User address
     * @return Array of payment IDs
     */
    function getUserPendingDrips(address user)
        external
        view
        returns (bytes32[] memory)
    {
        return userPendingDrips[user];
    }

    /**
     * @notice Update oracle address
     * @param newOracle New oracle address
     */
    function setOracle(address newOracle) external onlyOwner {
        address oldOracle = oracle;
        oracle = newOracle;
        emit OracleUpdated(oldOracle, newOracle);
    }

    /**
     * @notice Update Base Pay processor address
     * @param newProcessor New processor address
     */
    function setBasePayProcessor(address newProcessor) external onlyOwner {
        address oldProcessor = basePayProcessor;
        basePayProcessor = newProcessor;
        emit BasePayProcessorUpdated(oldProcessor, newProcessor);
    }

    /**
     * @notice Emergency withdrawal of tokens
     * @param token Token address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Helper functions
    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    uint256[50] private __gap;
}
