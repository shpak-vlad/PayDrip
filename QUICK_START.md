# Quick Start Guide

Get PayDrip running in 5 minutes! 🚀

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Private key with some ETH on Base
- Base Mainnet RPC access

## Step 1: Clone & Install

```bash
git clone https://github.com/shpak-vlad/PayDrip.git
cd PayDrip/contracts
forge install
```

## Step 2: Configure Environment

```bash
# Copy example
cp .env.example .env

# Edit .env file
nano .env
```

**Required (minimum):**
```bash
PRIVATE_KEY=0xYourPrivateKeyHere
PAYDRIP_PROXY=0x6f2bd18433b0aea1a10be7af88d3a6bbdd0f8b1e
```

**Optional (leave empty for now):**
```bash
ORACLE_ADDRESS=         # Will use your address
BASEPAY_PROCESSOR=      # Will use your address
BASESCAN_API_KEY=       # For contract verification
```

> 💡 **Tip:** ORACLE_ADDRESS and BASEPAY_PROCESSOR will automatically use your deployer address if left empty!

## Step 3: Get Your Address

```bash
# See what address will be used for oracle
forge script script/helpers/GetAddress.s.sol

# Output:
# ==============================================
# Your Address: 0xYourAddress
# ==============================================
```

## Step 4: Run Tests

```bash
# Run all tests
forge test -vv

# Run with gas report
forge test --gas-report

# Expected output:
# ✓ All tests passing
```

## Step 5: Deploy Integration Contracts

### Option A: Dry Run First (Recommended)

```bash
# Simulate deployment (no gas costs)
forge script script/DeployIntegrations.s.sol \
  --rpc-url https://mainnet.base.org
```

### Option B: Live Deployment

```bash
# Deploy to Base Mainnet
forge script script/DeployIntegrations.s.sol \
  --rpc-url https://mainnet.base.org \
  --broadcast \
  --verify

# Save the output addresses!
# BasePayDrip: 0x...
# PaymentLinkFactory: 0x...
# FiatQuoter: 0x...
```

## Step 6: Test Your Deployment

```javascript
// test-integration.js
const { ethers } = require('ethers');

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const basePayDrip = new ethers.Contract(
  'YOUR_BASEPAY_DRIP_ADDRESS',
  BASE_PAY_DRIP_ABI,
  provider
);

// Check oracle address
const oracle = await basePayDrip.oracle();
console.log('Oracle:', oracle); // Should be your address
```

## What's Next?

### For Testing
1. **Test Payment Flow** - Try creating a drip with fiat
2. **Manual Confirmation** - Confirm payments manually using your address
3. **Build Frontend** - Create UI for users

### For Production
1. **Setup Oracle Backend** - See [contracts/docs/ORACLE_SETUP.md](contracts/docs/ORACLE_SETUP.md)
2. **Base Pay Integration** - Connect to real Base Pay API
3. **Monitoring** - Setup alerts for payment confirmations

## Common Issues

### "Private key not found"
```bash
# Make sure .env has PRIVATE_KEY
echo "PRIVATE_KEY=0x..." >> .env
```

### "Insufficient funds"
```bash
# Your address needs ETH on Base for gas
# Bridge ETH to Base: https://bridge.base.org
```

### "Proxy not found"
```bash
# Make sure PAYDRIP_PROXY is set correctly
PAYDRIP_PROXY=0x6f2bd18433b0aea1a10be7af88d3a6bbdd0f8b1e
```

### "Oracle address is zero"
```bash
# This is OK! It will use your deployer address automatically
# Or set explicitly:
ORACLE_ADDRESS=0xYourAddress
```

## Using GitHub Actions

Instead of local deployment, use GitHub Actions:

1. **Setup Secrets** in GitHub repo
2. **Go to Actions** → Deploy Integrations
3. **Run workflow** with dry_run=true first
4. **Run again** with dry_run=false to deploy

See [.github/DEPLOYMENT.md](.github/DEPLOYMENT.md) for details.

## Resources

- 📖 [Full Documentation](contracts/docs/)
- 🔧 [Oracle Setup](contracts/docs/ORACLE_SETUP.md)
- 🚀 [Deployment Guide](.github/DEPLOYMENT.md)
- 📝 [Base Pay Integration](contracts/docs/BASE_PAY_INTEGRATION.md)

## Need Help?

- GitHub Issues: https://github.com/shpak-vlad/PayDrip/issues
- Base Docs: https://docs.base.org
- Foundry Book: https://book.getfoundry.sh

---

**Ready to deploy?** → Just run the commands above! 🎉
