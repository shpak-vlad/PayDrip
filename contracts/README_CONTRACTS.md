# Smart Contracts Documentation

## Core Contracts
- **PaymentStream.sol** - Main UUPS upgradeable streaming contract  
- **PaymentStreamProxy.sol** - UUPS proxy for upgrades

## Libraries
- **StreamLibrary.sol** - Stream calculation utilities  
- **DataTypes.sol** - Type conversion for packed storage

## Security Features
- ReentrancyGuard protection  
- Access control modifiers  
- Custom errors for gas efficiency  
- Packed storage (uint96/uint32)
