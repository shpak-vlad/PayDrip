# PayDrip V1 Deployment Guide

## Overview
PayDrip V1 implements minimal DripModule and StepModule functionality with UUPS upgradeable architecture.

## Deployment Workflows

### Base Sepolia Testnet
1. Navigate to Actions tab in GitHub
2. Select "Deploy PayDrip to Base Sepolia" workflow
3. Click "Run workflow"
4. Enable verification (default: true)
5. Wait for completion

**Deployment artifacts:**
- `contracts/broadcast/DeployPayDrip.s.sol/84532/run-latest.json`
- `contracts/deployments/paydrip-sepolia.json`

### Base Mainnet
1. Navigate to Actions tab in GitHub
2. Select "Deploy PayDrip to Base Mainnet" workflow
3. Click "Run workflow"
4. Enable verification (default: true)
5. Wait for completion

**Deployment artifacts:**
- `contracts/broadcast/DeployPayDrip.s.sol/8453/run-latest.json`
- `contracts/deployments/paydrip-mainnet.json`

## Required Secrets

Ensure these secrets are configured in GitHub repository settings:
- `PRIVATE_KEY` - Deployer private key for testnet
- `PRIVATE_KEY_MAINNET` - Deployer private key for mainnet
- `BASESCAN_API_KEY` - Basescan API key for contract verification

## Post-Deployment

After successful deployment:
1. Verify contracts on Basescan
2. Create drips on-chain to generate activity
3. Update frontend configuration with proxy addresses
4. Monitor deployment metadata files
