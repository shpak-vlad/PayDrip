# Oracle and Base Pay Configuration

## Overview

The Base Pay integration requires two special addresses:

### 1. ORACLE_ADDRESS
**Purpose:** Confirms fiat payments after Base Pay processes them

**What it does:**
- Calls `confirmPayment()` after successful fiat payment
- Calls `failPayment()` if payment fails
- Updates exchange rates in FiatQuoter

**Options:**

#### Option A: Use Your Own Address (Recommended for Start)
```bash
ORACLE_ADDRESS=0xYourDeployerAddress
```
**Pros:** Simple, immediate deployment
**Cons:** You manually confirm payments

#### Option B: Dedicated Oracle Service (Later)
Setup a backend service that:
1. Listens to Base Pay webhooks
2. Verifies payments on-chain
3. Calls `confirmPayment()` automatically

**Example backend:**
```javascript
// backend/oracle/basepay-oracle.js
app.post('/basepay/webhook', async (req, res) => {
  const { paymentId, status, amount } = req.body;

  if (status === 'completed') {
    await basePayDrip.confirmPayment(paymentId, USDC_ADDRESS);
  } else if (status === 'failed') {
    await basePayDrip.failPayment(paymentId, 'Payment declined');
  }
});
```

---

### 2. BASEPAY_PROCESSOR
**Purpose:** Alternative address that can also process Base Pay callbacks

**What it does:**
- Same as ORACLE_ADDRESS
- Can call payment confirmation functions
- Useful for backup/redundancy

**Options:**

#### Option A: Same as Oracle (Recommended)
```bash
BASEPAY_PROCESSOR=0xYourDeployerAddress
```

#### Option B: Separate Address
If you have a separate backend service:
```bash
BASEPAY_PROCESSOR=0xYourBackendServiceAddress
```

---

## Quick Start (MVP)

For immediate deployment and testing:

```bash
# In contracts/.env
ORACLE_ADDRESS=0xYourDeployerAddress
BASEPAY_PROCESSOR=0xYourDeployerAddress
```

This allows YOU to manually confirm payments while building the full integration.

**How to manually confirm a payment:**
```bash
# After someone initiates a fiat payment
cast send $BASEPAY_DRIP_ADDRESS \
  "confirmPayment(bytes32,address)" \
  $PAYMENT_ID \
  $USDC_ADDRESS \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## Production Setup (Full Integration)

### Step 1: Deploy Contracts
```bash
# Use your address initially
ORACLE_ADDRESS=0xYourAddress
BASEPAY_PROCESSOR=0xYourAddress
```

### Step 2: Create Oracle Backend

**File: `backend/oracle/index.js`**
```javascript
const express = require('express');
const { ethers } = require('ethers');

const app = express();
app.use(express.json());

// Contract setup
const provider = new ethers.JsonRpcProvider(process.env.BASE_RPC_URL);
const wallet = new ethers.Wallet(process.env.ORACLE_PRIVATE_KEY, provider);
const basePayDrip = new ethers.Contract(
  process.env.BASEPAY_DRIP_ADDRESS,
  BASE_PAY_DRIP_ABI,
  wallet
);

// Base Pay webhook
app.post('/webhook/basepay', async (req, res) => {
  const { payment_id, status, amount, currency } = req.body;

  // Verify webhook signature (Base Pay specific)
  if (!verifyBasePaySignature(req)) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  try {
    if (status === 'completed') {
      // Confirm payment on-chain
      const tx = await basePayDrip.confirmPayment(
        payment_id,
        USDC_ADDRESS
      );
      await tx.wait();

      console.log(`✓ Payment ${payment_id} confirmed`);
    } else if (status === 'failed') {
      const tx = await basePayDrip.failPayment(
        payment_id,
        'Payment failed'
      );
      await tx.wait();

      console.log(`✗ Payment ${payment_id} failed`);
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error processing payment:', error);
    res.status(500).json({ error: error.message });
  }
});

// Rate updates (every 5 minutes)
setInterval(async () => {
  try {
    const rates = await fetchRatesFromAPI();

    const tx = await fiatQuoter.batchUpdateRates(
      ['USD', 'EUR', 'GBP'],
      [rates.USD, rates.EUR, rates.GBP]
    );
    await tx.wait();

    console.log('✓ Rates updated');
  } catch (error) {
    console.error('Error updating rates:', error);
  }
}, 5 * 60 * 1000);

app.listen(3000, () => console.log('Oracle running on port 3000'));
```

### Step 3: Deploy Oracle Service
```bash
# Deploy to your server
cd backend/oracle
npm install
pm2 start index.js --name "basepay-oracle"
```

### Step 4: Update Contract (if needed)
```bash
# If oracle address needs to change
cast send $BASEPAY_DRIP_ADDRESS \
  "setOracle(address)" \
  $NEW_ORACLE_ADDRESS \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## Recommended Approach

### Phase 1: MVP (Now)
```bash
ORACLE_ADDRESS=0xYourDeployerAddress
BASEPAY_PROCESSOR=0xYourDeployerAddress
```
- Deploy contracts
- Manually test payment flow
- Build frontend

### Phase 2: Backend Integration (Next)
```bash
ORACLE_ADDRESS=0xBackendServerAddress
BASEPAY_PROCESSOR=0xBackendServerAddress
```
- Deploy oracle backend
- Setup Base Pay webhooks
- Automate payment confirmations

### Phase 3: Production (Later)
```bash
ORACLE_ADDRESS=0xDedicatedOracleAddress
BASEPAY_PROCESSOR=0xBackupProcessorAddress
```
- Dedicated infrastructure
- Monitoring & alerts
- Redundancy & failover

---

## Security Notes

1. **Private Keys**
   - Oracle needs its own private key
   - Keep separate from deployer key
   - Use hardware wallet for production

2. **Webhook Verification**
   - Always verify Base Pay signatures
   - Use HTTPS only
   - Implement rate limiting

3. **Access Control**
   - Only oracle can confirm payments
   - Owner can change oracle address
   - Monitor oracle activity

---

## Testing Without Base Pay

For testing the integration without actual Base Pay:

```javascript
// Test script
const paymentId = ethers.randomBytes(32);

// 1. Initiate payment
const { checkoutUrl } = await basePayDrip.initiateDripWithFiat(
  receiver,
  amountPerStep,
  totalSteps,
  interval,
  'http://localhost:3000/return'
);

// 2. Simulate oracle confirmation
await basePayDrip.confirmPayment(paymentId, USDC_ADDRESS);

// 3. Finalize drip
await basePayDrip.finalizeDrip(paymentId);
```

---

## FAQ

**Q: Can I use the same address for both?**
A: Yes! They can be the same address.

**Q: Can I change these addresses later?**
A: Yes, via `setOracle()` and `setBasePayProcessor()` functions.

**Q: What if I don't use Base Pay yet?**
A: Still set to your address. The contracts work fine without fiat payments.

**Q: Do I need to run a server?**
A: Only for automated payment confirmations. Manual works too.

---

## Quick Setup Command

```bash
# Get your address from private key
export MY_ADDRESS=$(cast wallet address $PRIVATE_KEY)

# Set environment variables
echo "ORACLE_ADDRESS=$MY_ADDRESS" >> contracts/.env
echo "BASEPAY_PROCESSOR=$MY_ADDRESS" >> contracts/.env
```

Now you can deploy! 🚀
