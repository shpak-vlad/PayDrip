# PayDrip

Decentralized micro-payment streaming platform on Base network. PayDrip enables efficient recurring payments and continuous fund streams using smart contracts with upgradeable proxy pattern.

## Features

- **Payment Streaming**: Continuous, time-based payment streams
- **Multi-Token Support**: Stream any ERC-20 token
- **Upgradeable Contracts**: UUPS proxy pattern for seamless upgrades
- **Smart Wallet Integration**: Coinbase Smart Wallet support
- **Base Network**: Built specifically for Base mainnet/testnet

## Architecture

- **Smart Contracts**: Solidity 0.8.23 with Foundry
- **Frontend**: React with ethers.js
- **Backend**: FastAPI for indexing and API
- **Network**: Base Sepolia (testnet) / Base Mainnet

## Project Structure

```
/app
├── contracts/          # Smart contracts (Foundry)
│   ├── src/           # Contract source files
│   ├── test/          # Contract tests
│   └── script/        # Deployment scripts
├── frontend/          # React application
└── backend/           # FastAPI server
```
