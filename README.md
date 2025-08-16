# BondMirror

**Synthetic Assets for Government and Corporate Bond Performance Tracking**

BondMirror is a decentralized finance (DeFi) protocol built on the Stacks blockchain that creates synthetic exposure to traditional bond assets. Users can track and trade synthetic representations of government and corporate bonds without needing to hold the underlying assets directly.

## 🌟 Features

- **Synthetic Bond Creation**: Create tokenized representations of government and corporate bonds
- **Real-time Price Tracking**: Oracle-based price feeds for accurate bond valuation
- **Collateralized Positions**: STX-backed synthetic bond positions with automatic settlement
- **Multiple Bond Types**: Support for both government bonds (treasury, municipal) and corporate bonds
- **Position Management**: Buy, sell, and track synthetic bond positions with P&L calculations
- **Oracle System**: Decentralized price feed system with authorized oracle management
- **Maturity Handling**: Automatic bond lifecycle management including maturity and deactivation

## 🏗 Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Token Standard**: SIP-010 Fungible Token (synthetic-bond)
- **Epoch**: 2.5
- **Test Framework**: Clarinet SDK with Vitest

### Key Components

- **Synthetic Bond Token**: Fungible token representing bond shares
- **Bond Registry**: On-chain storage of bond metadata and characteristics
- **Price Oracle System**: Real-time price updates from authorized oracles
- **Position Tracking**: User portfolio management with entry prices and P&L
- **Collateral Management**: STX-based collateralization for synthetic positions

## 📦 Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- [Node.js](https://nodejs.org/) v18+
- [Stacks CLI](https://docs.stacks.co/docs/stacks-cli)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd BondMirror
   ```

2. **Install dependencies**
   ```bash
   cd BondMirror_contract
   npm install
   ```

3. **Run tests**
   ```bash
   npm test
   ```

4. **Start local development**
   ```bash
   clarinet console
   ```

## 🚀 Usage Examples

### Creating a Bond

```clarity
;; Create a 10-year US Treasury bond
(contract-call? .BondMirror create-bond 
  u1                                    ;; Government bond type
  "US Treasury"                         ;; Issuer
  "UST10Y"                             ;; Symbol
  u1234567                             ;; Maturity block height
  u1000000000                          ;; Face value (1000 STX)
  u250                                 ;; 2.5% coupon rate (250 basis points)
  u980000000)                          ;; Initial price (980 STX - trading at discount)
```

### Buying Synthetic Bonds

```clarity
;; Purchase 100 shares of bond ID 1
(contract-call? .BondMirror buy-synthetic-bond u1 u100)
```

### Selling Synthetic Bonds

```clarity
;; Sell 50 shares of bond ID 1
(contract-call? .BondMirror sell-synthetic-bond u1 u50)
```

### Checking Position Value

```clarity
;; Get current position value for user
(contract-call? .BondMirror get-position-value 'SP1EXAMPLE... u1)

;; Get profit/loss for position
(contract-call? .BondMirror get-position-pnl 'SP1EXAMPLE... u1)
```

## 📋 Contract Functions Documentation

### Public Functions

#### Administrative Functions
- `initialize()` - Initialize contract and set up owner as oracle
- `create-bond()` - Create new synthetic bond with specified parameters
- `add-oracle()` - Add authorized price oracle (owner only)
- `remove-oracle()` - Remove oracle authorization (owner only)
- `deactivate-bond()` - Deactivate matured or delisted bonds (owner only)

#### Trading Functions
- `buy-synthetic-bond()` - Purchase synthetic bond shares with STX collateral
- `sell-synthetic-bond()` - Sell synthetic bond shares for STX payout
- `update-bond-price()` - Update bond price (authorized oracles only)

### Read-Only Functions

#### Bond Information
- `get-bond-info(bond-id)` - Retrieve bond metadata and characteristics
- `get-bond-price(bond-id)` - Get current price and 24h change data
- `get-total-bonds()` - Get total number of bonds created

#### Position Management
- `get-user-position(user, bond-id)` - Get user's position details
- `get-position-value(user, bond-id)` - Calculate current position value
- `get-position-pnl(user, bond-id)` - Calculate position profit/loss
- `get-synthetic-balance(user)` - Get user's synthetic token balance

#### System Information
- `get-contract-owner()` - Get contract owner address
- `is-authorized-oracle(oracle)` - Check if address is authorized oracle

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR_UNAUTHORIZED | Caller not authorized for this action |
| 101 | ERR_INVALID_AMOUNT | Invalid amount provided |
| 102 | ERR_INSUFFICIENT_BALANCE | Insufficient balance for operation |
| 103 | ERR_BOND_NOT_FOUND | Bond ID does not exist |
| 104 | ERR_BOND_EXPIRED | Bond has expired or is inactive |
| 105 | ERR_PRICE_TOO_OLD | Price data is stale (>24h old) |
| 106 | ERR_INVALID_BOND_TYPE | Invalid bond type specified |

## 🚀 Deployment Guide

### Testnet Deployment

1. **Configure network settings**
   ```bash
   cd BondMirror_contract
   # Edit settings/Testnet.toml for testnet configuration
   ```

2. **Deploy to testnet**
   ```bash
   clarinet deployments generate --devnet
   clarinet deployments apply -p devnet
   ```

3. **Initialize contract**
   ```bash
   clarinet console
   >> (contract-call? .BondMirror initialize)
   ```

### Mainnet Deployment

1. **Configure mainnet settings**
   ```bash
   # Edit settings/Mainnet.toml
   # Set appropriate deployment parameters
   ```

2. **Deploy to mainnet**
   ```bash
   clarinet deployments generate --mainnet
   clarinet deployments apply -p mainnet
   ```

3. **Post-deployment checklist**
   - Initialize contract
   - Add authorized oracles
   - Create initial bond offerings
   - Verify all functions work correctly

## 🔒 Security Notes

### Smart Contract Security

- **Access Control**: Only contract owner can create bonds and manage oracles
- **Price Validation**: All price updates must come from authorized oracles
- **Stale Price Protection**: Trades rejected if price data is older than 24 hours (144 blocks)
- **Collateral Management**: STX collateral held by contract for all synthetic positions
- **Input Validation**: All user inputs validated for correctness and safety

### Best Practices

1. **Oracle Security**: Only add trusted and reliable price oracles
2. **Price Freshness**: Ensure oracles update prices regularly (at least daily)
3. **Bond Lifecycle**: Properly manage bond maturity and deactivation
4. **Testing**: Thoroughly test all functions before mainnet deployment
5. **Monitoring**: Monitor contract state and oracle price feeds continuously

### Known Considerations

- Price oracle dependency: System relies on external price feeds
- Block height timing: Maturity dates based on block heights, not calendar dates
- STX volatility: Collateral value may fluctuate with STX price movements
- Liquidity: Synthetic bond liquidity depends on user participation

## 📊 Bond Types

### Government Bonds (Type 1)
- Treasury bonds
- Municipal bonds
- Sovereign debt instruments
- Government-backed securities

### Corporate Bonds (Type 2)
- Corporate debt securities
- High-yield bonds
- Investment-grade bonds
- Convertible bonds

## 🔧 Development

### Running Tests

```bash
npm test                # Run all tests
npm run test:report     # Run tests with coverage
npm run test:watch      # Watch mode for development
```

### Code Structure

```
BondMirror_contract/
├── contracts/
│   └── BondMirror.clar         # Main contract
├── tests/
│   └── BondMirror.test.ts      # Test suite
├── settings/
│   ├── Devnet.toml             # Devnet configuration
│   ├── Testnet.toml            # Testnet configuration
│   └── Mainnet.toml            # Mainnet configuration
├── Clarinet.toml               # Project configuration
├── package.json                # Dependencies
├── tsconfig.json               # TypeScript config
└── vitest.config.js            # Test configuration
```

## 📄 License

This project is licensed under the ISC License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📞 Support

For questions, issues, or contributions:
- Open an issue on GitHub
- Review the contract documentation
- Check the test suite for usage examples

---

**⚠️ Disclaimer**: This is experimental DeFi software. Use at your own risk. Always conduct thorough testing and audits before deploying to mainnet or investing significant funds.