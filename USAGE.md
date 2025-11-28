# PayDrip Usage Examples

## Creating a Drip

```solidity
// Create a drip that pays 100 USDC every 7 days for 10 steps
uint256 dripId = payDrip.createDrip(
    100e6,           // 100 USDC per step (6 decimals)
    10,              // 10 total steps
    7 days,          // 7 day interval between steps
    receiver,        // recipient address
    usdcAddress      // USDC token address
);
```

## Executing Steps

```solidity
// Execute the next step (manual trigger)
bool success = payDrip.executeStep(dripId);

// Returns true if step was executed
// Returns false if interval hasn't elapsed
```

## Querying Drip State

```solidity
(
    address sender,
    address receiver,
    address token,
    uint256 amountPerStep,
    uint256 totalSteps,
    uint256 currentStep,
    uint256 interval,
    uint256 lastExecuted,
    bool active
) = payDrip.getDrip(dripId);
```

## Cancelling a Drip

```solidity
// Sender can cancel and receive refund for remaining steps
payDrip.cancelDrip(dripId);
```

## Integration Patterns

### Automated Execution
Use Gelato or Chainlink Automation to execute steps automatically:

```solidity
contract DripExecutor {
    IPayDrip public payDrip;

    function executeIfReady(uint256 dripId) external {
        payDrip.executeStep(dripId);
    }
}
```

### Batch Drips
Create multiple drips for different recipients:

```solidity
address[] memory recipients = [alice, bob, charlie];
for (uint i = 0; i < recipients.length; i++) {
    payDrip.createDrip(100e6, 10, 7 days, recipients[i], usdc);
}
```

### Usage-Based Payments
Trigger payments based on external events:

```solidity
contract UsagePayments {
    IPayDrip public payDrip;

    function onServiceUsed(uint256 dripId) external {
        payDrip.executeStep(dripId);
    }
}
```

## Common Use Cases

### Creator Subscriptions
Monthly payments to content creators:
```solidity
createDrip(10e6, 12, 30 days, creator, usdc); // 10 USDC/month for 1 year
```

### Vesting Schedule
Team token vesting with quarterly unlocks:
```solidity
createDrip(10000e18, 4, 90 days, teamMember, projectToken); // 10k tokens every quarter
```

### Recurring Services
Payment for ongoing services:
```solidity
createDrip(50e6, 24, 14 days, serviceProvider, usdc); // 50 USDC bi-weekly for 48 weeks
```

## Events

Monitor drip activity by listening to events:

```javascript
payDrip.on("DripCreated", (dripId, sender, receiver, token, amountPerStep, totalSteps, interval) => {
    console.log(`New drip ${dripId} created`);
});

payDrip.on("StepExecuted", (dripId, stepNumber, amount, receiver) => {
    console.log(`Step ${stepNumber} executed for drip ${dripId}`);
});

payDrip.on("DripCompleted", (dripId) => {
    console.log(`Drip ${dripId} completed`);
});
```
