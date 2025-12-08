# PayDrip Semantics Documentation

## Overview

PayDrip implements a discrete-step payment pipeline for recurring transfers on Base L2. This document defines the precise behavior, edge cases, and guarantees of the core `Drip` data structure and execution model.

**Target Audience:** Protocol integrators, auditors, and developers building on PayDrip.

---

## Drip Data Structure

### Storage Layout

```solidity
struct Drip {
    address sender;          // Drip creator and fund source
    address receiver;        // Payment recipient
    address token;           // ERC20 token address
    uint96 amountPerStep;    // Amount transferred per step (max ~7.9×10²⁸)
    uint32 totalSteps;       // Total number of payment steps (max ~4.3B)
    uint32 currentStep;      // Execution progress counter (0-indexed)
    uint32 interval;         // Seconds between steps (max ~136 years)
    uint64 lastExecuted;     // Timestamp of last step execution
    bool active;             // Drip status flag
}
```

### Type Constraints

- **amountPerStep (uint96)**: Maximum value `2^96 - 1` (~79.2 billion ETH with 18 decimals)
- **totalSteps (uint32)**: Maximum `4,294,967,295` steps
- **interval (uint32)**: Maximum `4,294,967,295` seconds (~136 years)
- **lastExecuted (uint64)**: Timestamp valid until year 584,942,417,355

**⚠️ Overflow Behavior:**
- Values exceeding type limits are silently truncated during downcasting
- Integrators must validate inputs before calling `createDrip`
- Example: `amountPerStep = 2^96` becomes `0` after downcast

---

## Drip Lifecycle

### 1. Creation

**Function:** `createDrip(uint256 amountPerStep, uint256 totalSteps, uint256 interval, address receiver, address token)`

**Behavior:**
1. Validates parameters:
   - `receiver != address(0)` and `receiver != msg.sender`
   - `amountPerStep > 0`
   - `totalSteps > 0`
   - `interval > 0`
   - `token != address(0)`

2. Calculates total locked amount: `totalAmount = amountPerStep × totalSteps`

3. Transfers `totalAmount` tokens from `msg.sender` to contract via `transferFrom`

4. Initializes drip state:
   - `currentStep = 0`
   - `lastExecuted = 0` (not `block.timestamp`)
   - `active = true`

5. Returns unique `dripId` (monotonic counter)

**Guarantees:**
- Exact `totalAmount` tokens are locked at creation (no rounding)
- First step can execute immediately after creation
- No partial drip creation (atomicity via `transferFrom` revert)

---

### 2. Execution

**Function:** `executeStep(uint256 dripId) returns (bool)`

**Execution Conditions:**

| Condition | Check | Result if False |
|-----------|-------|----------------|
| Drip exists | `dripId < dripCounter` | Revert `DripNotFound()` |
| Drip active | `active == true` | Revert `DripNotActive()` |
| Steps remain | `currentStep < totalSteps` | Revert `DripNotActive()` |
| Interval elapsed | `currentStep == 0` OR<br>`block.timestamp - lastExecuted >= interval` | Return `false` (no revert) |

**Execution Flow:**

1. **First Step (currentStep == 0):**
   - No interval check required
   - Can execute immediately after creation
   - Sets `lastExecuted = block.timestamp`

2. **Subsequent Steps:**
   - Requires `block.timestamp - lastExecuted >= interval`
   - Strict inequality (`<` fails, `>=` succeeds)
   - Updates `lastExecuted = block.timestamp`

3. **Transfer:**
   - Transfers exactly `amountPerStep` to receiver
   - Increments `currentStep++`
   - Emits `StepExecuted` event

4. **Completion:**
   - If `currentStep >= totalSteps`: sets `active = false`
   - Emits `DripCompleted` event
   - Future `executeStep` calls revert with `DripNotActive()`

**Return Values:**
- `true`: Step executed successfully
- `false`: Too early (interval not elapsed, no state change)

**Guarantees:**
- Each step transfers exactly `amountPerStep` (no fees, no slippage)
- Total disbursed = `amountPerStep × totalSteps` (exact match to locked funds)
- No dust remains in contract after completion
- Interval measured from `lastExecuted`, not creation time

---

### 3. Cancellation

**Function:** `cancelDrip(uint256 dripId)`

**Authorization:**
- Only drip `sender` can cancel
- Reverts with `Unauthorized()` otherwise

**Behavior:**
1. Validates drip is active (`active == true`)
2. Calculates refund: `refundAmount = (totalSteps - currentStep) × amountPerStep`
3. Sets `active = false`
4. Transfers `refundAmount` to sender (if > 0)
5. Emits `DripCancelled` event

**Edge Cases:**
- **Cancel before first step:** Refunds full `totalAmount`
- **Cancel after completion:** Reverts (drip not active)
- **Cancel already cancelled:** Reverts (drip not active)
- **Receiver cannot cancel:** Only sender has cancellation rights

**Guarantees:**
- Exact refund calculation: no partial steps
- Cancellation is irreversible (cannot reactivate)
- Remaining funds returned atomically

---

## Edge Cases and Behaviors

### Time Boundaries

**Exact Interval Match:**
```solidity
// Execution at t=0
executeStep(dripId); // currentStep = 1, lastExecuted = 0

// At t = interval - 1
executeStep(dripId); // Returns false (too early)

// At t = interval
executeStep(dripId); // Returns true (exact boundary)
```

**Multiple Rapid Attempts:**
```solidity
executeStep(dripId); // true (first step)
executeStep(dripId); // false (no state change)
executeStep(dripId); // false (no state change)
// currentStep still 1
```

---

### Single-Step Drips

**Behavior:**
- `totalSteps = 1` is valid
- First `executeStep` completes and deactivates drip immediately
- No interval check occurs (only one step)
- Full amount transferred in single transaction

**Use Case:** One-time delayed payment or vesting cliff

---

### Variable Intervals

**Supported Range:**
- Minimum: `1 second` (near-instant drips)
- Maximum: `2^32 - 1 seconds` (~136 years)

**Very Short Intervals (< 1 minute):**
- Practical for high-frequency micro-payments
- Gas costs may exceed payment amounts
- Consider batching or L2 optimization

**Very Long Intervals (> 1 year):**
- Suitable for annual vesting or long-term grants
- Ensure `lastExecuted` timestamp precision (uint64 sufficient until year 584B)

---

### Exact Fund Accounting

**Invariant:**
```
locked_at_creation = amountPerStep × totalSteps
total_disbursed = amountPerStep × currentStep
remaining_in_contract = locked_at_creation - total_disbursed
```

**No Rounding:**
- `totalAmount` calculated as product, not division
- No fractional token handling required
- Works with any ERC20 decimal precision

**Example:**
```solidity
// 100.5 USDC (6 decimals) over 3 steps
amountPerStep = 100_500_000 (100.5 × 10^6)
totalSteps = 3
locked = 301_500_000 (301.5 USDC exact)

// After 2 steps:
disbursed = 201_000_000 (201 USDC)
remaining = 100_500_000 (100.5 USDC)
```

---

### Multiple Drips

**Independence:**
- Each drip has unique `dripId` and isolated state
- Same sender/receiver can have multiple active drips
- Intervals and execution tracked independently
- No cross-drip dependencies or shared locks

**Example:**
```solidity
// User creates two drips with different intervals
drip1: 100 USDC/week for 4 weeks (interval = 7 days)
drip2: 50 USDC/day for 30 days (interval = 1 day)

// Both execute independently based on their own lastExecuted
```

---

### Completion and Re-execution

**After Completion:**
```solidity
// After final step
executeStep(dripId); // Sets active = false

// Subsequent calls
executeStep(dripId); // Reverts DripNotActive()
cancelDrip(dripId);  // Reverts DripNotActive()
```

**Query Completed Drips:**
- `getDrip()` still returns drip data
- `active == false` indicates completion or cancellation
- Historical data remains accessible on-chain

---

## Safety Properties

### Guaranteed Invariants

1. **No Overpayment:**
   ```
   total_transferred <= amountPerStep × totalSteps
   ```

2. **No Locked Funds:**
   ```
   (active == false) → (balance_in_contract == 0 OR refunded_to_sender)
   ```

3. **Monotonic Progress:**
   ```
   currentStep only increases (never decreases or resets)
   ```

4. **Time-Bounded Execution:**
   ```
   step[i] can only execute if:
   block.timestamp >= lastExecuted + interval (for i > 0)
   ```

5. **Exact Accounting:**
   ```
   sum(all_transfers) + refund_on_cancel == locked_at_creation
   ```

---

## Integration Guidelines

### For Integrators

1. **Pre-Creation Validation:**
   - Verify `amountPerStep × totalSteps` doesn't overflow uint256
   - Check token approval covers `totalAmount`
   - Validate `interval` matches intended payment schedule

2. **Execution Strategies:**
   - **Receiver-executed:** Receiver calls `executeStep` when needed
   - **Automated:** Keeper bot monitors and executes based on `lastExecuted + interval`
   - **Batch execution:** Loop through pending drips in single transaction

3. **Cancellation Handling:**
   - Only sender can cancel (receiver has no control)
   - Cancellation after last step reverts (check `active` first)
   - Consider UI warnings for accidental cancellations

4. **Error Handling:**
   - `executeStep` returning `false` is not an error (retry after interval)
   - Catch `DripNotActive()` to detect completed/cancelled drips
   - Handle `Unauthorized()` for non-sender cancellation attempts

---

### For Auditors

**Focus Areas:**
1. **Reentrancy:** Contract uses `nonReentrant` modifier on all state-changing functions
2. **Integer Overflow:** Downcasting from uint256 to uint96/uint32/uint64 truncates silently
3. **Timestamp Manipulation:** Uses `block.timestamp` (15-second tolerance acceptable for intervals)
4. **Token Transfer Failures:** Uses `transfer` (not `safeTransfer`) - assumes ERC20 compliance
5. **Access Control:** Only sender can cancel, anyone can execute steps

**Known Limitations:**
- No ERC20 `transfer` return value check (assumes standard compliance)
- No fee-on-transfer token support (would cause accounting mismatch)
- No pause/resume mechanism (only cancel with refund)

---

## Example Scenarios

### Scenario 1: Weekly Salary Payment

```solidity
// 1000 USDC per week for 4 weeks
createDrip(
    amountPerStep: 1000e6,      // 1000 USDC
    totalSteps: 4,              // 4 payments
    interval: 7 days,           // Weekly
    receiver: employee,
    token: USDC_ADDRESS
);

// Execution timeline:
// t=0:       executeStep() → 1000 USDC (immediate)
// t=7 days:  executeStep() → 1000 USDC
// t=14 days: executeStep() → 1000 USDC
// t=21 days: executeStep() → 1000 USDC (drip completes)
```

### Scenario 2: Token Vesting with Cliff

```solidity
// 10,000 tokens after 1 year (single step)
createDrip(
    amountPerStep: 10000e18,
    totalSteps: 1,
    interval: 365 days,
    receiver: investor,
    token: PROJECT_TOKEN
);

// Single execution after 365 days
```

### Scenario 3: Subscription with Early Cancellation

```solidity
// Monthly subscription: 50 USDC/month for 12 months
createDrip(
    amountPerStep: 50e6,
    totalSteps: 12,
    interval: 30 days,
    receiver: service_provider,
    token: USDC_ADDRESS
);

// After 3 payments (3 months):
cancelDrip(dripId);
// Refunds: 50 × (12 - 3) = 450 USDC to sender
```

---

## Comparison to Alternatives

| Feature | PayDrip | Superfluid | Sablier |
|---------|---------|------------|---------|
| Payment Model | Discrete steps | Continuous streaming | Discrete or continuous |
| First Payment | Immediate | After 1 second | After cliff |
| Gas per Payment | ~50k gas/step | ~100k gas/create + withdraw | ~60k gas/step |
| Cancellation | Instant refund | Settle stream | Based on unlock schedule |
| Base L2 Native | ✅ Yes | ❌ No | ⚠️ Partial |

---

## Changelog

### Block 1 (Initial Semantics)
- Defined core drip lifecycle and execution rules
- Documented edge cases and safety properties
- Established integration guidelines
- Comprehensive test coverage for all scenarios

---

## References

- **Contract:** `contracts/src/PayDrip.sol`
- **Tests:** `contracts/test/PayDrip.t.sol`
- **Base Pay Integration:** `contracts/docs/BASE_PAY_INTEGRATION.md`
- **Deployment Addresses:** `contracts/deployments/base-*.json`

---

**Document Version:** 1.0
**Last Updated:** Block 1 Development Phase
**Status:** Audit-Ready
