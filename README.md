# shredcore-copytrade-bot

A high-performance Solana copytrading bot written in Rust for maximum efficiency. This bot automatically monitors specific wallet addresses and copies their trades on PumpFun and PumpSwap platforms, allowing you to follow successful traders automatically.

## Why Rust?

This bot is written in Rust, a systems programming language known for its exceptional performance, memory safety, and low latency. Rust's zero-cost abstractions and efficient execution make it ideal for high-frequency trading where every millisecond counts. The bot can detect and copy trades faster than bots written in interpreted languages, giving you a competitive edge by following successful traders in real-time.

## Performance

This is one of the **speediest bot on the market**. With optimal server, RPC, and gRPC provider configuration, the bot can achieve **0 to 3 blocks landing speed** after signal detection. This exceptional speed ensures you copy trades almost simultaneously with the target wallet, minimizing price slippage and maximizing your ability to mirror successful traders' entry points.

## Durable Nonce Technology

This bot uses **Durable Nonce** technology, which is essential for its operation. Here's why:  
When trading at high speeds, the bot sends the same transaction to multiple SWQoS (Solana Quality of Service) providers simultaneously - including Jito, Nozomi (Temporal), and Astralane. This "spam sending" strategy dramatically improves transaction inclusion speed and success rates by ensuring your transaction reaches validators through multiple paths.
However, without durable nonces, sending the same transaction to multiple providers could result in duplicate executions if multiple providers include it in the same block. Durable nonces solve this by ensuring each transaction can only be executed once, even if it's submitted through multiple channels. This allows the bot to safely spam transactions to all available SWQoS providers for maximum speed and inclusion probability, while preventing accidental double-spends.

## Supported Platforms

- **PumpFun** - The original bonding curve platform
- **PumpSwap** - After migration from bonding curves
... Many more to come

## Features

### Copytrading Core

- **Wallet Monitoring**: Tracks specific wallet addresses (target wallets) for their trading activity
- **Automatic Buy Copying**: Automatically buys the same tokens when target wallets buy
- **Buy Size Scaling**: Optionally scale your buy size based on the target wallet's buy size (percentage-based)
- **Sell Mirroring**: Optionally mirror target wallet sells, either proportionally or fully
- **New Position Filtering**: Option to only copy trades for tokens the target just opened (skip existing positions)

### Entry Strategy

- **Immediate Entry**: Buy immediately when target wallet buys (most aggressive)
- **Dip Entry Gates**: Wait for favorable dip conditions before entering (more conservative)
- **Profit Confirmation**: Optional feature to wait and see if target's position becomes profitable before copying
- **Hold Confirmation**: Verify target still holds the position before entering (prevents copying late)

### Risk Management

- **Stop Loss**: Automatically sell if your position drops below a configured loss percentage
- **Take Profit Levels**: Set multiple profit targets with partial sell percentages
- **Dynamic Trailing Stop Loss (DTSL)**: As your profit increases, the stop loss floor automatically raises to lock in gains
- **Time-Based Exits**: Force exits after maximum hold time, negative PnL duration, or minimum profit target duration
- **Position Limits**: Control maximum concurrent positions
- **Portfolio Exposure Limits**: Limit total capital deployed across all positions

### Advanced Trading Features

- **Dollar Cost Averaging (DCA)**: Automatically add to losing positions to average down entry price
- **Transaction Retries**: Automatic retry logic for failed transactions with exponential backoff
- **Blacklist**: Permanently block specific token mints from trading

### Execution Features

- **SWQoS Integration**: Simultaneously sends transactions to multiple providers (Jito, Nozomi, Astralane) for maximum inclusion speed
- **Priority Fees**: Configurable fees to encourage faster validator inclusion
- **High Slippage Tolerance**: Configured for aggressive entry/exit to ensure trades execute
- **Real-Time Market Data**: Uses gRPC (Yellowstone) or WebSocket streams for instant market updates

## Setup and Installation

### Prerequisites

- Solana CLI tools (for nonce setup)
- A Solana wallet with SOL for trading
- A license key
- RPC endpoint (high-performance private RPC recommended)
- gRPC endpoint (Yellowstone gRPC) or WebSocket endpoint
- Target wallet addresses to follow (public keys of traders you want to copy)

### Quick Start

1. **Configure the bot**:
   ```bash
   ./start.sh
   ```
   
   The interactive setup script will guide you through:
   - License key entry
   - RPC and gRPC/WebSocket URL configuration
   - Wallet private key (Base58 encoded)

2. **Setup Durable Nonce**:
   The setup script automatically runs `setup_nonce.sh` if no nonce account exists. This creates a durable nonce account that's required for safe multi-provider transaction sending.

3. **Configure Target Wallets**:
   
   Edit `config.toml` to add wallets to follow:
   ```toml
   TARGET_WALLETS = [
     "11111111111111111111111111111111",  # Replace with actual wallet pubkey
     "22222222222222222222222222222222",  # Add more wallets as needed
   ]
   ```

5. **Configure Copytrade Settings**:
   
   Edit `config.toml` to customize behavior:
   - `FOLLOW_TARGET_BUY_SIZE`: Scale buy size based on target's buy (true/false)
   - `SCALE_TARGET_BUY_SIZE`: Percentage of target's buy size to copy (0-100)
   - `ENABLE_ENTRY_DIP`: Wait for dip conditions before entering (true/false)
   - `FOLLOW_TARGET_SELLS`: Mirror target wallet sells (true/false)
   - `MATCH_TARGET_SELL_SIZING`: Match sell percentage or always exit 100% (true/false)

4. **Launch the bot**:
   ```bash
   ./start.sh
   ```
   
   Or if you've already configured:
   ```bash
   ./rust-copytrade
   ```

### Manual Configuration

1. Copy the example config:
   ```bash
   cp config.example.toml config.toml
   ```

2. Edit `config.toml` with your settings:
   - `LICENSE_KEY`: Your license key
   - `RPC_URL`: Your Solana RPC endpoint
   - `GRPC_URL`: Your Yellowstone gRPC endpoint (if using gRPC)
   - `WALLET_PRIVATE_KEY_B58`: Your wallet private key in Base58 format
   - `TARGET_WALLETS`: Array of wallet public keys to follow
   - Configure copytrade behavior settings
   - Adjust trading parameters (buy amounts, stop loss, take profit, etc.)

3. Setup durable nonce:
   ```bash
   ./setup_nonce.sh
   ```

4. Run the bot:
   ```bash
   ./rust-copytrade
   ```

### Configuration File

The `config.toml` file contains all bot settings organized into sections:

- `[config]`: Connection settings, wallet, license, and nonce configuration
- `[trading]`: Trading parameters, risk management, and copytrade-specific settings
- `[scoring]`: Market analysis filters (used when entry dip gates are enabled)

See `config.example.toml` for detailed comments on each setting.

## Usage

### Normal Operation

Simply run `./start.sh` or `./rust-copytrade` and the bot will:
1. Connect to market data streams
2. Monitor target wallets for buy transactions
3. Automatically execute buy orders when target wallets buy (based on your configuration)
4. Optionally mirror target wallet sells
5. Manage positions with your configured risk management rules
6. Execute sells based on stop loss, take profit, or time-based rules

### Command Line Interface

You can also manually trigger trades:

**Buy a specific token**:
```bash
./rust-copytrade --buy <MINT_ADDRESS> [--platform PUMP_FUN|PUMP_SWAP]
```

**Sell a position**:
```bash
./rust-copytrade --sell <MINT_ADDRESS>
```

### Logs

Logs are saved to `.logs/solana-trading-bot.log` by default (can be disabled in config). Monitor this file to track bot activity, trades, target wallet activity, and any issues.

## Configuration Tips

### Copytrade Settings

- **Buy Size Scaling**: Set `FOLLOW_TARGET_BUY_SIZE = true` and `SCALE_TARGET_BUY_SIZE = 75.0` to copy 75% of target's buy size
- **Entry Strategy**: 
  - `ENABLE_ENTRY_DIP = false` for immediate copying (fastest, most aggressive)
  - `ENABLE_ENTRY_DIP = true` for dip-based entry (more conservative, may miss some opportunities)
- **Profit Confirmation**: Enable `WAIT_FOR_MONITORED_PROFIT` to only copy after target shows profit
- **Hold Confirmation**: Enable `CONFIRM_TARGET_STILL_HOLDS` to verify target hasn't sold before copying
- **Sell Mirroring**: Enable `FOLLOW_TARGET_SELLS` to automatically exit when target exits

### Finding Target Wallets

Look for successful traders on:
- Solana blockchain explorers (Solscan, SolanaFM)
- Trading leaderboards
- Social media (Discord, Twitter) where traders share their addresses
- Trading communities and groups

**Important**: Only follow wallets you trust. The bot will copy all trades from target wallets, so choose carefully.

## Important Notes

- **Durable Nonce is Required**: The bot requires a durable nonce account for safe operation with multiple SWQoS providers. The setup script handles this automatically.

- **High-Performance RPC Recommended**: For best results, use a private, high-performance RPC endpoint. Public RPCs may have rate limits and higher latency.

- **Wallet Security**: Never share your `WALLET_PRIVATE_KEY_B58`. Keep your `config.toml` file secure and never commit it to version control.

- **Start with Small Amounts**: When first using the bot, start with small `BUY_AMOUNT_SOL` values or low `SCALE_TARGET_BUY_SIZE` percentages to test your configuration.

- **Simulation Mode**: Use `SIMULATE = true` in your config to test without risking real SOL.

- **Choose Targets Wisely**: The bot copies all trades from target wallets. Only follow wallets you trust and have verified are profitable traders.

- **Timing Matters**: Even with fast execution, you may enter at slightly different prices than the target wallet. This is normal and expected.

## Troubleshooting

- **"Durable nonce file not found"**: Run `./setup_nonce.sh` manually
- **"License validation failed"**: Check your `LICENSE_KEY` in config.toml
- **"Failed to create trade-stream client"**: Verify your `GRPC_URL` or `WS_URL` is correct
- **No trades executing**: 
  - Verify `TARGET_WALLETS` contains valid wallet addresses
  - Check that target wallets are actively trading
  - Verify entry gates aren't too restrictive
- **Transactions failing**: Check your wallet has sufficient SOL for trades and fees
- **Copying too late**: Enable immediate entry (`ENABLE_ENTRY_DIP = false`) or reduce confirmation requirements

## Support

For issues, questions, or feature requests, please contact support through your license provider.

