# PayDrip Smart Contracts

Upgradeable payment streaming contracts built with Foundry for Base network.

## Dependencies

- Foundry
- OpenZeppelin Contracts v5.0.2
- Solidity 0.8.23

## Setup

```bash
forge install
forge build
forge test
```

## Contracts

- `PaymentStream.sol` - Core payment streaming logic
- `PaymentStreamProxy.sol` - UUPS upgradeable proxy

## Testing

```bash
forge test -vvv
forge coverage
```

## Deployment

```bash
# Base Sepolia Testnet
forge script script/Deploy.s.sol --rpc-url base_testnet --broadcast

# Base Mainnet
forge script script/Deploy.s.sol --rpc-url base_mainnet --broadcast --verify
```
