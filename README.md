# PayDrip

Automated micro-payment pipeline for Base network. Create programmable payment sequences with discrete steps, variable timing, and event-driven execution.

## Features
- **Discrete Drips**: Step-based payments instead of continuous streaming
- **Flexible Timing**: Interval-based, event-driven, or manual execution
- **UUPS Upgradeable**: Safe upgrade path for future enhancements
- **Multi-token Support**: Compatible with any ERC20 token
- **Base Optimized**: Built specifically for Base L2 ecosystem

## Architecture

### V1 Core Modules
- **DripModule**: Create and manage payment sequences
- **StepModule**: Track execution state and progress

### Smart Contracts
- `PayDrip.sol` - Core contract with UUPS upgradeability
- `PaymentStreamProxy.sol` - ERC1967 proxy for upgrades

## Networks
- **Base Sepolia**: Testnet deployment
- **Base Mainnet**: Production deployment

## Development

```bash
# Install dependencies
cd contracts && forge install

# Run tests
forge test -vv

# Deploy (via GitHub Actions)
# See DEPLOYMENT_V1.md for instructions
```

## Tech Stack
- Solidity 0.8.23
- Foundry
- OpenZeppelin Upgradeable Contracts
- Base L2
