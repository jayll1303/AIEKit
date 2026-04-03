# Freqtrade CLI Commands

## Data Download

```bash
# Download data for pairs in config
freqtrade download-data --config config.json --timeframes 5m 1h --days 30

# Download specific pairs
freqtrade download-data --exchange binance --pairs ETH/USDT BTC/USDT --timeframes 5m 1h

# All USDT pairs
freqtrade download-data --exchange binance --pairs ".*/USDT" --timeframes 5m

# Futures data
freqtrade download-data --config config.json --trading-mode futures --timeframes 5m 1h

# List available data
freqtrade list-data --userdir user_data --show-timerange
```

## Backtesting

```bash
# Basic
freqtrade backtesting --strategy MyStrategy --config config.json

# With timerange
freqtrade backtesting --strategy MyStrategy --timerange 20240101-20240601 --timeframe 5m

# Compare strategies
freqtrade backtesting --strategy-list Strategy1 Strategy2 --timeframe 5m

# With breakdown
freqtrade backtesting --strategy MyStrategy --breakdown month year
```

For hyperopt and other commands, see `references/cli-hyperopt-utils.md`.
