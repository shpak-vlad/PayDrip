# Deployment Metadata

This directory contains deployment metadata for each network.

## Structure

Each deployment creates a JSON file: `{network}.json`

### Example: base-sepolia.json

```json
{
  "network": "base-sepolia",
  "chainId": 84532,
  "contracts": {
    "PayDrip": {
      "implementation": "0x...",
      "proxy": "0x..."
    }
  },
  "deployer": "0x...",
  "timestamp": "2025-11-28T15:30:00Z",
  "version": "v1"
}
```

## Files

- `base-sepolia.json` - Base Sepolia testnet deployment
- `base-mainnet.json` - Base Mainnet production deployment

**Proxy addresses are permanent. Implementations can be upgraded.**
