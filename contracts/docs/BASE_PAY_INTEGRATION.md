# Base Pay API Integration

## Overview

This integration enables seamless fiat-to-crypto on-ramp for PayDrip drip creation using the Base Pay API. Users can create drips with fiat payments, generate shareable payment links, and get real-time fiat conversion quotes.

## Architecture

### Core Contracts

#### 1. BasePayDrip
**Purpose**: Bridge between Base Pay fiat on-ramp and drip creation

**Key Features**:
- Initiate drip creation with fiat payment
- Handle payment confirmation callbacks from Base Pay oracle
- Finalize drip creation after payment confirmation
- Track pending drips awaiting payment

**Key Functions**:
```solidity
initiateDripWithFiat(receiver, amountPerStep, totalSteps, interval, returnUrl)
confirmPayment(paymentId, token) // Called by oracle
failPayment(paymentId, reason) // Called by oracle
finalizeDrip(paymentId) // Creates actual drip after payment confirmed
```

**Payment Flow**:
1. User calls `initiateDripWithFiat()`
2. Contract generates paymentId and checkout URL
3. User completes fiat payment via Base Pay
4. Oracle calls `confirmPayment()` after verification
5. User calls `finalizeDrip()` to create the drip in PayDrip contract

#### 2. PaymentLinkFactory
**Purpose**: Generate shareable payment links for drip creation

**Key Features**:
- Create single-use or multi-use payment links
- Support both crypto and fiat payments
- Link expiry and validation
- Track link usage and associated drips

**Key Functions**:
```solidity
createPaymentLink(receiver, amountPerStep, totalSteps, interval, expiry, memo, token, multiUse)
payViaLink(linkId) // Pay with crypto
payViaLinkWithFiat(linkId, returnUrl) // Pay with fiat via Base Pay
cancelLink(linkId)
isLinkValid(linkId)
```

**Use Cases**:
- Subscription payment links
- Invoice payment links
- Donation links
- Recurring payment requests

#### 3. FiatQuoter
**Purpose**: Provide real-time fiat to crypto conversion quotes

**Key Features**:
- Support multiple fiat currencies (USD, EUR, GBP)
- Oracle-based rate updates
- Quote validity periods
- Fee calculation
- Stale rate detection

**Key Functions**:
```solidity
getQuote(usdcAmount, fiatCurrency) // Get simple quote
estimateDripCost(amountPerStep, totalSteps, fiatCurrency) // Estimate total drip cost
getDetailedQuote(usdcAmount, fiatCurrency) // Get detailed quote with metadata
updateRate(currency, newRate) // Oracle updates rate
```

## Deployment

### Prerequisites
- PayDrip proxy deployed
- USDC contract address on Base
- Oracle address for payment confirmation
- Base Pay processor address

### Deployment Steps

1. **Deploy BasePayDrip**
```solidity
BasePayDrip implementation = new BasePayDrip();
bytes memory initData = abi.encodeWithSelector(
    BasePayDrip.initialize.selector,
    payDripAddress,
    oracleAddress,
    basePayProcessorAddress
);
PaymentStreamProxy proxy = new PaymentStreamProxy(address(implementation), initData);
```

2. **Deploy PaymentLinkFactory**
```solidity
PaymentLinkFactory implementation = new PaymentLinkFactory();
bytes memory initData = abi.encodeWithSelector(
    PaymentLinkFactory.initialize.selector,
    payDripAddress,
    basePayDripAddress
);
PaymentStreamProxy proxy = new PaymentStreamProxy(address(implementation), initData);
```

3. **Deploy FiatQuoter**
```solidity
FiatQuoter implementation = new FiatQuoter();
bytes memory initData = abi.encodeWithSelector(
    FiatQuoter.initialize.selector,
    oracleAddress
);
PaymentStreamProxy proxy = new PaymentStreamProxy(address(implementation), initData);
```

## Integration Guide

### Frontend Integration

#### Create Drip with Fiat
```typescript
// 1. Initiate fiat payment
const { paymentId, checkoutUrl } = await basePayDrip.initiateDripWithFiat(
  receiverAddress,
  amountPerStep,
  totalSteps,
  interval,
  returnUrl
);

// 2. Redirect user to checkoutUrl
window.location.href = checkoutUrl;

// 3. After payment, oracle confirms (backend)
await basePayDrip.confirmPayment(paymentId, usdcAddress);

// 4. Finalize drip creation
const dripId = await basePayDrip.finalizeDrip(paymentId);
```

#### Create and Share Payment Link
```typescript
// Create link
const linkId = await linkFactory.createPaymentLink(
  receiverAddress,
  amountPerStep,
  totalSteps,
  interval,
  expiryTimestamp,
  "Monthly subscription",
  usdcAddress,
  true // multiUse
);

// Share link URL
const linkUrl = `https://paydrip.app/pay/${linkId}`;

// Pay via link (user perspective)
const dripId = await linkFactory.payViaLink(linkId);
```

#### Get Fiat Quote
```typescript
// Get quote for drip cost
const fiatAmount = await fiatQuoter.estimateDripCost(
  amountPerStep,
  totalSteps,
  "USD"
);

console.log(`Total cost: ${fiatAmount / 1e6} USD`);

// Get detailed quote
const quote = await fiatQuoter.getDetailedQuote(totalAmount, "USD");
console.log(`Rate: ${quote.rate}`);
console.log(`Valid until: ${quote.validUntil}`);
```

### Oracle Integration

#### Payment Confirmation Oracle
The oracle monitors Base Pay payment events and calls confirmation functions:

```typescript
// Listen for Base Pay payment success
basePayAPI.on('payment.success', async (event) => {
  const { paymentId, amount, token } = event;

  // Verify payment on-chain
  const verified = await verifyPayment(paymentId);

  if (verified) {
    // Confirm payment in BasePayDrip contract
    await basePayDrip.confirmPayment(paymentId, token);
  } else {
    await basePayDrip.failPayment(paymentId, "Verification failed");
  }
});
```

#### Rate Update Oracle
Updates fiat exchange rates periodically:

```typescript
// Update rates every 5 minutes
setInterval(async () => {
  const rates = await fetchRatesFromAPI(['USD', 'EUR', 'GBP']);

  await fiatQuoter.batchUpdateRates(
    ['USD', 'EUR', 'GBP'],
    [rates.USD, rates.EUR, rates.GBP]
  );
}, 5 * 60 * 1000);
```

## Security Considerations

1. **Oracle Trust**: Oracle must be trusted to confirm payments correctly
2. **Payment Timeout**: Pending payments expire after 24 hours
3. **Rate Staleness**: Quotes become stale after 5 minutes
4. **Authorization**: Only oracle can confirm/fail payments
5. **Reentrancy**: All external calls protected with ReentrancyGuard
6. **Upgradeability**: All contracts are UUPS upgradeable

## Testing

```bash
# Run all Base Pay integration tests
forge test --match-contract BasePayDripTest -vv

# Run payment link tests
forge test --match-contract PaymentLinkFactoryTest -vv

# Run all integration tests
forge test --match-path "test/BasePayDrip.t.sol" --match-path "test/PaymentLinkFactory.t.sol" -vv
```

## Configuration

### Deployed Addresses (Base Mainnet)
- PayDrip Proxy: `0x6f2bd18433b0aea1a10be7af88d3a6bbdd0f8b1e`
- USDC: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- BasePayDrip: TBD
- PaymentLinkFactory: TBD
- FiatQuoter: TBD

### Oracle Configuration
- Payment confirmation timeout: 24 hours
- Quote validity: 5 minutes
- Rate validity: 1 hour
- Default fee: 0.5% (50 basis points)

## Future Enhancements

1. **Multi-token support**: Support tokens beyond USDC
2. **Custom fee structures**: Per-link or per-user fee configurations
3. **Subscription templates**: Pre-configured payment link templates
4. **Analytics dashboard**: Track payment volumes and conversion rates
5. **Webhook integration**: Direct Base Pay webhook callbacks
6. **Gasless transactions**: Meta-transactions for better UX
