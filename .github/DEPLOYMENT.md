# Deployment & Upgrade Guide

This guide covers how to deploy new contracts and upgrade existing ones using GitHub Actions.

## Prerequisites

### GitHub Secrets

Configure the following secrets in your repository settings (`Settings → Secrets and variables → Actions`):

#### Required for all networks:
- `DEPLOYER_PRIVATE_KEY` - Private key for deployment account
- `BASESCAN_API_KEY` - API key for contract verification

#### Base Mainnet:
- `BASE_MAINNET_RPC_URL` - RPC endpoint (default: https://mainnet.base.org)
- `PAYDRIP_PROXY` - Address of PayDrip proxy: `0x6f2bd18433b0aea1a10be7af88d3a6bbdd0f8b1e`
- `ORACLE_ADDRESS` - Address for oracle (Base Pay integration)
- `BASEPAY_PROCESSOR` - Address for Base Pay processor

#### Base Sepolia (Testnet):
- `BASE_SEPOLIA_RPC_URL` - RPC endpoint (default: https://sepolia.base.org)

## Workflows

### 1. Tests (Automatic)

**Trigger:** Runs automatically on push/PR to `dev` or `main` branches

**What it does:**
- Runs all Foundry tests
- Checks contract sizes
- Generates gas reports
- Checks code formatting
- Calculates code coverage

**View:** Actions → Tests

---

### 2. Deploy Integrations (Manual)

**Purpose:** Deploy BasePayDrip, PaymentLinkFactory, and FiatQuoter contracts

**How to run:**

1. Go to **Actions → Deploy Integrations → Run workflow**

2. Select options:
   - **Network:** `base-sepolia` (testnet) or `base-mainnet` (production)
   - **Dry run:** `true` to simulate, `false` to actually deploy

3. Click **Run workflow**

**What happens:**

**Dry Run (recommended first):**
```bash
✓ Runs all tests
✓ Simulates deployment
✓ Shows what would be deployed
✗ Does NOT broadcast transactions
```

**Live Deployment:**
```bash
✓ Runs all tests
✓ Deploys BasePayDrip implementation + proxy
✓ Deploys PaymentLinkFactory implementation + proxy
✓ Deploys FiatQuoter implementation + proxy
✓ Verifies contracts on Basescan
✓ Saves deployment info to artifacts
✓ Posts comment with contract addresses
```

**Artifacts:** Download deployment JSON from workflow run

---

### 3. Upgrade PayDrip (Manual)

**Purpose:** Upgrade existing PayDrip proxy to new implementation

**⚠️ IMPORTANT:** This upgrades a live contract. Test thoroughly first!

**How to run:**

1. Go to **Actions → Upgrade PayDrip → Run workflow**

2. Fill in:
   - **Network:** `base-sepolia` or `base-mainnet`
   - **Dry run:** `true` to simulate, `false` to upgrade
   - **Confirmation:** Type `UPGRADE` to confirm

3. Click **Run workflow**

**What happens:**

**Dry Run (ALWAYS run first):**
```bash
✓ Runs all tests
✓ Deploys new implementation
✓ Simulates upgrade transaction
✓ Verifies compatibility
✗ Does NOT broadcast transactions
```

**Live Upgrade:**
```bash
✓ Runs all tests
✓ Deploys new implementation
✓ Calls upgradeToAndCall() on proxy
✓ Verifies upgrade was successful
✓ Verifies contract on Basescan
✓ Saves upgrade info to artifacts
```

**Safety checks:**
- Requires typing "UPGRADE" to confirm
- Runs all tests before upgrade
- Verifies upgrade after completion

---

## Manual Deployment (Local)

### Deploy Integrations

```bash
cd contracts

# Create .env file
cp .env.example .env

# Fill in variables:
# PRIVATE_KEY=...
# PAYDRIP_PROXY=0x6f2bd18433b0aea1a10be7af88d3a6bbdd0f8b1e
# ORACLE_ADDRESS=...
# BASEPAY_PROCESSOR=...
# BASESCAN_API_KEY=...

# Dry run (simulate)
forge script script/DeployIntegrations.s.sol \
  --rpc-url $BASE_RPC_URL

# Live deployment
forge script script/DeployIntegrations.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify
```

### Upgrade PayDrip

```bash
cd contracts

# Dry run (simulate)
forge script script/UpgradePayDrip.s.sol \
  --rpc-url $BASE_RPC_URL

# Live upgrade
forge script script/UpgradePayDrip.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify
```

---

## Deployment Checklist

### Before Deploying to Mainnet:

- [ ] All tests pass on dev branch
- [ ] Code review completed
- [ ] Deploy to Base Sepolia first
- [ ] Test on Sepolia thoroughly
- [ ] Run dry run on mainnet
- [ ] Verify all secrets are set
- [ ] Backup deployment keys
- [ ] Notify team of deployment

### After Deployment:

- [ ] Verify contracts on Basescan
- [ ] Update README with new addresses
- [ ] Test contract interactions
- [ ] Update frontend with new addresses
- [ ] Document any issues
- [ ] Create GitHub release

---

## Troubleshooting

### Workflow fails with "Secret not found"

**Solution:** Add missing secrets in repository settings

### Deployment transaction fails

**Solution:** Check:
- Sufficient ETH for gas
- Correct RPC URL
- Valid private key
- Network not congested

### Upgrade fails with "Unauthorized"

**Solution:** Verify deployer is owner of proxy contract

### Contract verification fails

**Solution:**
- Check BASESCAN_API_KEY is valid
- Wait a few minutes and try again
- Manually verify on Basescan

---

## Security Notes

1. **Never commit private keys** - Use GitHub secrets only
2. **Test on Sepolia first** - Always test before mainnet
3. **Use dry runs** - Simulate before live deployment
4. **Verify contracts** - Always verify on Basescan
5. **Keep backups** - Save deployment artifacts
6. **Audit upgrades** - Review code changes before upgrading

---

## Support

- GitHub Issues: https://github.com/shpak-vlad/PayDrip/issues
- Documentation: [contracts/docs/](../contracts/docs/)
- Base Docs: https://docs.base.org
