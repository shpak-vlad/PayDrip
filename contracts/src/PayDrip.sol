// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PayDrip is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    struct Drip {
        address sender;
        address receiver;
        address token;
        uint96 amountPerStep;
        uint32 totalSteps;
        uint32 currentStep;
        uint32 interval;
        uint64 lastExecuted;
        bool active;
    }

    mapping(uint256 => Drip) public drips;
    mapping(address => uint256[]) public userDrips;

    uint256 public dripCounter;
    uint256 public totalDripsCreated;
    uint256 public totalVolumeScheduled;

    event DripCreated(
        uint256 indexed dripId,
        address indexed sender,
        address indexed receiver,
        address token,
        uint256 amountPerStep,
        uint256 totalSteps,
        uint256 interval
    );

    event StepExecuted(
        uint256 indexed dripId,
        uint256 stepNumber,
        uint256 amount,
        address indexed receiver
    );

    event DripCompleted(uint256 indexed dripId);
    event DripCancelled(uint256 indexed dripId, uint256 refundAmount);

    error InvalidReceiver();
    error InvalidAmount();
    error InvalidSteps();
    error InvalidInterval();
    error DripNotFound();
    error Unauthorized();
    error DripNotActive();
    error InsufficientBalance();

    modifier dripExists(uint256 dripId) {
        if (dripId >= dripCounter) revert DripNotFound();
        _;
    }

    modifier onlyDripSender(uint256 dripId) {
        if (drips[dripId].sender != msg.sender) revert Unauthorized();
        _;
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        dripCounter = 0;
        totalDripsCreated = 0;
        totalVolumeScheduled = 0;
    }

    function createDrip(
        uint256 amountPerStep,
        uint256 totalSteps,
        uint256 interval,
        address receiver,
        address token
    ) external nonReentrant returns (uint256) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (receiver == msg.sender) revert InvalidReceiver();
        if (amountPerStep == 0) revert InvalidAmount();
        if (totalSteps == 0) revert InvalidSteps();
        if (interval == 0) revert InvalidInterval();
        if (token == address(0)) revert InvalidAmount();

        uint256 totalAmount = amountPerStep * totalSteps;

        IERC20(token).transferFrom(msg.sender, address(this), totalAmount);

        uint256 dripId = dripCounter++;

        drips[dripId] = Drip({
            sender: msg.sender,
            receiver: receiver,
            token: token,
            amountPerStep: uint96(amountPerStep),
            totalSteps: uint32(totalSteps),
            currentStep: 0,
            interval: uint32(interval),
            lastExecuted: 0,
            active: true
        });

        userDrips[msg.sender].push(dripId);
        userDrips[receiver].push(dripId);

        totalDripsCreated++;
        totalVolumeScheduled += totalAmount;

        emit DripCreated(
            dripId,
            msg.sender,
            receiver,
            token,
            amountPerStep,
            totalSteps,
            interval
        );

        return dripId;
    }

    function getDrip(uint256 dripId)
        external
        view
        dripExists(dripId)
        returns (
            address sender,
            address receiver,
            address token,
            uint256 amountPerStep,
            uint256 totalSteps,
            uint256 currentStep,
            uint256 interval,
            uint256 lastExecuted,
            bool active
        )
    {
        Drip memory drip = drips[dripId];
        return (
            drip.sender,
            drip.receiver,
            drip.token,
            uint256(drip.amountPerStep),
            uint256(drip.totalSteps),
            uint256(drip.currentStep),
            uint256(drip.interval),
            uint256(drip.lastExecuted),
            drip.active
        );
    }

    function getUserDrips(address user) external view returns (uint256[] memory) {
        return userDrips[user];
    }

    function executeStep(uint256 dripId)
        external
        nonReentrant
        dripExists(dripId)
        returns (bool)
    {
        Drip storage drip = drips[dripId];

        if (!drip.active) revert DripNotActive();
        if (drip.currentStep >= drip.totalSteps) revert DripNotActive();

        if (drip.currentStep > 0) {
            uint256 timeSinceLastExecution = block.timestamp - drip.lastExecuted;
            if (timeSinceLastExecution < drip.interval) {
                return false;
            }
        }

        uint256 amount = drip.amountPerStep;
        drip.currentStep++;
        drip.lastExecuted = uint64(block.timestamp);

        IERC20(drip.token).transfer(drip.receiver, amount);

        emit StepExecuted(dripId, drip.currentStep, amount, drip.receiver);

        if (drip.currentStep >= drip.totalSteps) {
            drip.active = false;
            emit DripCompleted(dripId);
        }

        return true;
    }

    function cancelDrip(uint256 dripId)
        external
        nonReentrant
        dripExists(dripId)
        onlyDripSender(dripId)
    {
        Drip storage drip = drips[dripId];

        if (!drip.active) revert DripNotActive();

        uint256 remainingSteps = drip.totalSteps - drip.currentStep;
        uint256 refundAmount = remainingSteps * drip.amountPerStep;

        drip.active = false;

        if (refundAmount > 0) {
            IERC20(drip.token).transfer(drip.sender, refundAmount);
        }

        emit DripCancelled(dripId, refundAmount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[50] private __gap;
}
