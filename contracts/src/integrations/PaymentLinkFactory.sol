// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPayDrip.sol";
import "./BasePayDrip.sol";

/**
 * @title PaymentLinkFactory
 * @notice Generate and manage shareable payment links for drip creation
 * @dev Allows creating reusable payment links that anyone can use to create drips
 */
contract PaymentLinkFactory is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
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

    IPayDrip public payDrip;
    BasePayDrip public basePayDrip;

    mapping(bytes32 => PaymentLink) public paymentLinks;
    mapping(address => bytes32[]) public userLinks;
    mapping(bytes32 => uint256[]) public linkDrips;

    uint256 public linkCounter;
    uint256 public totalLinksCreated;
    uint256 public totalLinksUsed;

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

    error InvalidReceiver();
    error InvalidAmount();
    error InvalidSteps();
    error InvalidInterval();
    error InvalidToken();
    error InvalidExpiry();
    error LinkNotFound();
    error LinkExpired();
    error LinkAlreadyUsed();
    error Unauthorized();
    error LinkNotActive();

    function initialize(address _payDrip, address _basePayDrip) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        payDrip = IPayDrip(_payDrip);
        basePayDrip = BasePayDrip(_basePayDrip);
        linkCounter = 0;
        totalLinksCreated = 0;
        totalLinksUsed = 0;
    }

    /**
     * @notice Create a shareable payment link
     * @param receiver Address to receive drip payments
     * @param amountPerStep Amount per drip step
     * @param totalSteps Total number of steps
     * @param interval Time between steps in seconds
     * @param expiry Link expiration timestamp
     * @param memo Human-readable description
     * @param token Token address for payments
     * @param multiUse Whether link can be used multiple times
     * @return linkId Unique link identifier
     */
    function createPaymentLink(
        address receiver,
        uint256 amountPerStep,
        uint256 totalSteps,
        uint256 interval,
        uint256 expiry,
        string calldata memo,
        address token,
        bool multiUse
    ) external returns (bytes32 linkId) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (amountPerStep == 0) revert InvalidAmount();
        if (totalSteps == 0) revert InvalidSteps();
        if (interval == 0) revert InvalidInterval();
        if (token == address(0)) revert InvalidToken();
        if (expiry <= block.timestamp) revert InvalidExpiry();

        linkId = keccak256(
            abi.encodePacked(
                msg.sender,
                receiver,
                amountPerStep,
                totalSteps,
                interval,
                block.timestamp,
                linkCounter++
            )
        );

        uint256 totalAmount = amountPerStep * totalSteps;

        paymentLinks[linkId] = PaymentLink({
            linkId: linkId,
            creator: msg.sender,
            receiver: receiver,
            amountPerStep: amountPerStep,
            totalSteps: totalSteps,
            interval: interval,
            expiry: expiry,
            used: false,
            multiUse: multiUse,
            memo: memo,
            token: token,
            createdAt: block.timestamp,
            usageCount: 0
        });

        userLinks[msg.sender].push(linkId);
        totalLinksCreated++;

        emit LinkCreated(
            linkId,
            msg.sender,
            receiver,
            totalAmount,
            expiry,
            multiUse
        );

        return linkId;
    }

    /**
     * @notice Pay via link with crypto
     * @param linkId Link identifier
     * @return dripId Created drip ID
     */
    function payViaLink(bytes32 linkId)
        external
        nonReentrant
        returns (uint256 dripId)
    {
        PaymentLink storage link = paymentLinks[linkId];

        _validateLink(link, linkId);

        uint256 totalAmount = link.amountPerStep * link.totalSteps;

        // Transfer tokens from payer
        IERC20(link.token).transferFrom(msg.sender, address(this), totalAmount);

        // Approve PayDrip to spend tokens
        IERC20(link.token).approve(address(payDrip), totalAmount);

        // Create drip
        dripId = payDrip.createDrip(
            link.amountPerStep,
            link.totalSteps,
            link.interval,
            link.receiver,
            link.token
        );

        // Update link usage
        if (!link.multiUse) {
            link.used = true;
        }
        link.usageCount++;
        linkDrips[linkId].push(dripId);
        totalLinksUsed++;

        emit LinkUsed(linkId, msg.sender, dripId, false);

        return dripId;
    }

    /**
     * @notice Pay via link with fiat on-ramp
     * @param linkId Link identifier
     * @param returnUrl URL to return after payment
     * @return paymentId Base Pay payment ID
     * @return checkoutUrl Base Pay checkout URL
     */
    function payViaLinkWithFiat(bytes32 linkId, string calldata returnUrl)
        external
        returns (bytes32 paymentId, string memory checkoutUrl)
    {
        PaymentLink storage link = paymentLinks[linkId];

        _validateLink(link, linkId);

        // Initiate fiat payment via BasePayDrip
        (paymentId, checkoutUrl) = basePayDrip.initiateDripWithFiat(
            link.receiver,
            link.amountPerStep,
            link.totalSteps,
            link.interval,
            returnUrl
        );

        // Update link usage
        if (!link.multiUse) {
            link.used = true;
        }
        link.usageCount++;
        totalLinksUsed++;

        emit LinkUsed(linkId, msg.sender, 0, true);

        return (paymentId, checkoutUrl);
    }

    /**
     * @notice Cancel a payment link
     * @param linkId Link identifier
     */
    function cancelLink(bytes32 linkId) external {
        PaymentLink storage link = paymentLinks[linkId];

        if (link.creator == address(0)) revert LinkNotFound();
        if (link.creator != msg.sender) revert Unauthorized();
        if (link.used && !link.multiUse) revert LinkAlreadyUsed();

        link.expiry = block.timestamp;
        link.used = true;

        emit LinkCancelled(linkId, msg.sender);
    }

    /**
     * @notice Get link information
     * @param linkId Link identifier
     * @return Link details
     */
    function getLinkInfo(bytes32 linkId)
        external
        view
        returns (PaymentLink memory)
    {
        return paymentLinks[linkId];
    }

    /**
     * @notice Check if link is valid and usable
     * @param linkId Link identifier
     * @return Whether link is valid
     */
    function isLinkValid(bytes32 linkId) external view returns (bool) {
        PaymentLink storage link = paymentLinks[linkId];

        if (link.creator == address(0)) return false;
        if (block.timestamp > link.expiry) return false;
        if (link.used && !link.multiUse) return false;

        return true;
    }

    /**
     * @notice Get all links created by a user
     * @param user User address
     * @return Array of link IDs
     */
    function getUserLinks(address user) external view returns (bytes32[] memory) {
        return userLinks[user];
    }

    /**
     * @notice Get all drips created via a link
     * @param linkId Link identifier
     * @return Array of drip IDs
     */
    function getLinkDrips(bytes32 linkId) external view returns (uint256[] memory) {
        return linkDrips[linkId];
    }

    /**
     * @notice Validate link before use
     * @param link Link storage reference
     * @param linkId Link identifier for error messages
     */
    function _validateLink(PaymentLink storage link, bytes32 linkId) internal view {
        if (link.creator == address(0)) revert LinkNotFound();
        if (block.timestamp > link.expiry) revert LinkExpired();
        if (link.used && !link.multiUse) revert LinkAlreadyUsed();
    }

    /**
     * @notice Update PayDrip contract address
     * @param newPayDrip New PayDrip address
     */
    function setPayDrip(address newPayDrip) external onlyOwner {
        payDrip = IPayDrip(newPayDrip);
    }

    /**
     * @notice Update BasePayDrip contract address
     * @param newBasePayDrip New BasePayDrip address
     */
    function setBasePayDrip(address newBasePayDrip) external onlyOwner {
        basePayDrip = BasePayDrip(newBasePayDrip);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[50] private __gap;
}
