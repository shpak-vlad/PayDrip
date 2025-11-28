// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IPayDrip {
    struct DripInfo {
        address sender;
        address receiver;
        address token;
        uint256 amountPerStep;
        uint256 totalSteps;
        uint256 currentStep;
        uint256 interval;
        uint256 lastExecuted;
        bool active;
    }

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

    function createDrip(
        uint256 amountPerStep,
        uint256 totalSteps,
        uint256 interval,
        address receiver,
        address token
    ) external returns (uint256 dripId);

    function getDrip(uint256 dripId)
        external
        view
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
        );

    function executeStep(uint256 dripId) external returns (bool);

    function cancelDrip(uint256 dripId) external;

    function getUserDrips(address user) external view returns (uint256[] memory);
}
