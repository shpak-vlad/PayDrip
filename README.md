# PayDrip

Programmable micro-payment pipeline for Base. Discrete step-based payments with interval control, variable amounts, and event-driven execution.

## Architecture

PayDrip implements a **step-based payment system** fundamentally different from continuous streaming. Each drip is a sequence of discrete micro-payments executed at specific intervals or triggers.

### Core Model

```solidity
Drip {
  amountPerStep: 100 USDC
  totalSteps: 10
  interval: 7 days
  currentStep: 0/10
}
```

**Execution Flow:**
1. Create drip → locks total funds (100 × 10 = 1000 USDC)
2. Execute step 1 → transfers 100 USDC after 0 days
3. Execute step 2 → transfers 100 USDC after 7 days
4. ... continues until step 10
5. Drip completed → all funds distributed

### UUPS Upgradeable

```
┌─────────────────┐
│  PayDrip Proxy  │ ← User interacts (address never changes)
└────────┬────────┘
         │ delegatecall
         ▼
┌─────────────────┐
│ Implementation  │ ← Can be upgraded
│   (V1, V2...)   │
└─────────────────┘
```

**One proxy per network, upgrades change implementation only.**

## Contracts

### PayDrip.sol
Core logic with DripModule and StepModule:

**DripModule:**
- `createDrip(amountPerStep, totalSteps, interval, receiver, token)`
- `getDrip(dripId)`
- `cancelDrip(dripId)`

**StepModule:**
- `executeStep(dripId)` with interval validation
- Tracks `currentStep` and `lastExecuted`
- Auto-completes when `currentStep == totalSteps`

**Storage:**
- 50 slots reserved for future upgrades (`__gap`)
- UUPS pattern via OpenZeppelin

### PaymentStreamProxy.sol
Standard ERC1967 proxy for UUPS pattern.

## Usage

### Create Drip

```solidity
// 10 payments of 50 USDC every 14 days
uint256 dripId = payDrip.createDrip(
    50e6,        // 50 USDC (6 decimals)
    10,          // 10 steps
    14 days,     // interval
    0xReceiver,  // recipient
    USDC_ADDRESS // token
);
```

### Execute Step

```solidity
// Manual execution
bool success = payDrip.executeStep(dripId);
// Returns false if interval hasn't passed

// Automated via Gelato/Chainlink
contract Executor {
    function execute(uint256 dripId) external {
        payDrip.executeStep(dripId);
    }
}
```

### Query State

```solidity
(
    address sender,
    address receiver,
    address token,
    uint256 amountPerStep,
    uint256 totalSteps,
    uint256 currentStep,  // 0-10
    uint256 interval,
    uint256 lastExecuted,
    bool active
) = payDrip.getDrip(dripId);

// Progress: currentStep / totalSteps
// Next execution: lastExecuted + interval
```

### Cancel & Refund

```solidity
// Sender can cancel anytime
payDrip.cancelDrip(dripId);
// Refunds: (totalSteps - currentStep) * amountPerStep
```

## Use Cases

**Creator Subscriptions**
```solidity
createDrip(10e6, 12, 30 days, creator, USDC);
// 10 USDC monthly for 1 year
```

**Team Vesting**
```solidity
createDrip(25000e18, 4, 90 days, member, TOKEN);
// 25k tokens quarterly for 1 year
```

**Service Payments**
```solidity
createDrip(100e6, 24, 7 days, provider, USDC);
// 100 USDC weekly for 24 weeks
```

**Usage-Based Billing**
```solidity
// Trigger on events instead of time
contract UsageBilling {
    function onServiceUsed(uint256 dripId) external {
        payDrip.executeStep(dripId);
    }
}
```

## Events

```solidity
event DripCreated(dripId, sender, receiver, token, amountPerStep, totalSteps, interval)
event StepExecuted(dripId, stepNumber, amount, receiver)
event DripCompleted(dripId)
event DripCancelled(dripId, refundAmount)
```

## Networks

**Base Sepolia:** Testing and development
**Base Mainnet:** Production deployments

Deployment addresses in `contracts/deployments/*.json`

## Development

```bash
cd contracts

# Install dependencies
forge install

# Run tests
forge test -vv

# Build
forge build
```

## Integration

### Frontend Example

```javascript
const drip = await payDrip.createDrip(
    ethers.parseUnits("100", 6),  // 100 USDC
    10,
    7 * 24 * 60 * 60,  // 7 days
    receiverAddress,
    USDC_ADDRESS
);

// Monitor progress
payDrip.on("StepExecuted", (dripId, step, amount) => {
    console.log(`Step ${step} executed: ${amount}`);
});
```

### Automation Example

```javascript
// Chainlink Automation compatible
function checkUpkeep(bytes calldata checkData) external view returns (bool, bytes memory) {
    uint256 dripId = abi.decode(checkData, (uint256));
    (,,,,,, uint256 interval, uint256 lastExecuted, bool active) = payDrip.getDrip(dripId);

    bool needsExecution = active && (block.timestamp >= lastExecuted + interval);
    return (needsExecution, checkData);
}

function performUpkeep(bytes calldata performData) external {
    uint256 dripId = abi.decode(performData, (uint256));
    payDrip.executeStep(dripId);
}
```

## Tech Stack

- Solidity 0.8.23
- Foundry
- OpenZeppelin Upgradeable
- Base L2
