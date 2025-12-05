# PayDrip 💧

> Programmable micro-payment pipeline on Base L2. Create recurring payments, subscriptions, vesting, and more with fiat on-ramp support.

[![Base](https://img.shields.io/badge/Base-0052FF?style=for-the-badge&logo=ethereum&logoColor=white)](https://base.org)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.23-363636?style=for-the-badge&logo=solidity)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

## 🚀 Features

### Core Functionality
- **📅 Discrete Step Payments** - Execute payments at specific intervals or events
- **💰 Fiat On-Ramp** - Pay with credit card via Base Pay integration
- **🔗 Payment Links** - Share payment links for easy subscriptions
- **💱 Real-time Quotes** - Fiat-to-crypto conversion with multiple currencies
- **🔄 UUPS Upgradeable** - Future-proof smart contracts
- **⚡ Gas Optimized** - Efficient on Base L2

### Use Cases
- 📺 **Creator Subscriptions** - Monthly payments to content creators
- 👥 **Team Vesting** - Token distribution for team members
- 🏢 **Service Payments** - Weekly/monthly service invoices
- 💳 **Usage-Based Billing** - Event-driven payment execution
- 🎁 **Recurring Donations** - Automated charitable giving

## 📦 Quick Start

### For Users

#### 1. Create a Drip with Crypto

```javascript
import { PayDrip } from '@paydrip/sdk';

const drip = await payDrip.createDrip({
  receiver: '0xReceiverAddress',
  amountPerStep: '100', // 100 USDC
  totalSteps: 12,
  interval: 30 * 24 * 60 * 60, // 30 days
  token: USDC_ADDRESS
});
// 💸 12 monthly payments of 100 USDC
```

#### 2. Create a Drip with Fiat (Credit Card)

```javascript
const { paymentId, checkoutUrl } = await basePayDrip.initiateDripWithFiat({
  receiver: '0xReceiverAddress',
  amountPerStep: '50',
  totalSteps: 6,
  interval: 7 * 24 * 60 * 60, // 7 days
  returnUrl: 'https://yourapp.com/success'
});

// Redirect user to checkoutUrl for credit card payment
window.location.href = checkoutUrl;
```

#### 3. Create a Payment Link

```javascript
const linkId = await linkFactory.createPaymentLink({
  receiver: '0xReceiverAddress',
  amountPerStep: '25',
  totalSteps: 4,
  interval: 14 * 24 * 60 * 60, // 14 days
  expiry: Date.now() + 30 * 24 * 60 * 60 * 1000, // 30 days
  memo: 'Premium Subscription',
  multiUse: true
});

// Share link: https://paydrip.app/pay/{linkId}
```

### For Developers

```bash
# Clone repository
git clone https://github.com/shpak-vlad/PayDrip.git
cd PayDrip/contracts

# Install dependencies
forge install

# Run tests
forge test -vv

# Deploy
forge script script/Deploy.s.sol --rpc-url base --broadcast
```

## 🏗️ Architecture

### Core Contracts

#### PayDrip.sol
Main contract for drip creation and execution.

```solidity
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
```

#### BasePayDrip.sol
Fiat on-ramp integration via Base Pay API.

**Features:**
- Credit card to crypto conversion
- Oracle-based payment confirmation
- Automatic drip creation after payment

#### PaymentLinkFactory.sol
Generate shareable payment links.

**Features:**
- Single-use or multi-use links
- Crypto and fiat payment options
- Link expiration and validation

#### FiatQuoter.sol
Real-time fiat-to-crypto quotes.

**Features:**
- Support for USD, EUR, GBP
- Oracle-based rate updates
- Fee calculation

### Execution Flow

```
┌──────────────┐
│ User creates │
│    drip      │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌─────────────┐
│ Lock funds   │────▶│ Step 1      │
│ (1000 USDC)  │     │ Transfer    │
└──────────────┘     │ 100 USDC    │
                     └──────┬──────┘
                            │ Wait 30 days
                            ▼
                     ┌─────────────┐
                     │ Step 2      │
                     │ Transfer    │
                     │ 100 USDC    │
                     └──────┬──────┘
                            │ ...
                            ▼
                     ┌─────────────┐
                     │ Step 10     │
                     │ Completed   │
                     └─────────────┘
```

## 🌐 Deployments

### Base Mainnet
- **PayDrip Proxy**: `0x6f2bd18433b0aea1a10be7af88d3a6bbdd0f8b1e`
- **USDC**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **BasePayDrip**: TBD
- **PaymentLinkFactory**: TBD
- **FiatQuoter**: TBD

### Base Sepolia (Testnet)
- **PayDrip Proxy**: See `contracts/deployments/base-sepolia.json`

## 📖 Documentation

- [Base Pay Integration Guide](contracts/docs/BASE_PAY_INTEGRATION.md)
- [Deployment Guide](contracts/DEPLOYMENT.md)
- [Security](contracts/SECURITY.md)
- [Testing](contracts/TESTING.md)
- [Gas Report](contracts/GAS_REPORT.md)

## 🔐 Security

- ✅ UUPS Upgradeable pattern
- ✅ ReentrancyGuard on all external functions
- ✅ Oracle verification for fiat payments
- ✅ Payment timeout protection (24 hours)
- ✅ Comprehensive test coverage

**Audit Status**: Pending

## 🛠️ Tech Stack

- **Blockchain**: Base L2 (Optimistic Rollup)
- **Language**: Solidity 0.8.23
- **Framework**: Foundry
- **Libraries**: OpenZeppelin Upgradeable
- **Integration**: Base Pay API

## 💡 Examples

### Monthly Subscription

```solidity
// User subscribes to premium content
payDrip.createDrip(
    10e6,        // 10 USDC/month
    12,          // 12 months
    30 days,     // Monthly
    creator,
    USDC
);
```

### Team Vesting

```solidity
// 100k tokens vesting quarterly over 1 year
payDrip.createDrip(
    25000e18,    // 25k tokens
    4,           // 4 quarters
    90 days,     // Quarterly
    teamMember,
    TOKEN
);
```

### Service Payment

```solidity
// Weekly service payment for 6 months
payDrip.createDrip(
    100e6,       // 100 USDC/week
    24,          // 24 weeks
    7 days,      // Weekly
    provider,
    USDC
);
```

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

## 🔗 Links

- **Website**: https://paydrip.app (coming soon)
- **Documentation**: https://docs.paydrip.app (coming soon)
- **Base**: https://base.org
- **GitHub**: https://github.com/shpak-vlad/PayDrip

## 🙏 Acknowledgments

Built on [Base](https://base.org) - the secure, low-cost, builder-friendly Ethereum L2 by Coinbase.

---

**Made with ❤️ for the Base ecosystem**
