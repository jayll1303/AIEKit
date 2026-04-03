# Freqtrade Configuration

## Minimal Config Structure

```json
{
    "$schema": "https://schema.freqtrade.io/schema.json",
    "trading_mode": "spot",
    "margin_mode": "",
    "max_open_trades": 3,
    "stake_currency": "USDT",
    "stake_amount": "unlimited",
    "dry_run": true,
    "dry_run_wallet": 1000,
    "timeframe": "5m",
    "exchange": {
        "name": "binance",
        "key": "",
        "secret": "",
        "pair_whitelist": ["BTC/USDT", "ETH/USDT"],
        "pair_blacklist": []
    },
    "entry_pricing": { "price_side": "same", "use_order_book": true, "order_book_top": 1 },
    "exit_pricing": { "price_side": "same", "use_order_book": true, "order_book_top": 1 },
    "pairlists": [{ "method": "StaticPairList" }],
    "stoploss": -0.10,
    "minimal_roi": { "0": 0.04, "30": 0.02, "60": 0 }
}
```

## Futures Config Additions

```json
{
    "trading_mode": "futures",
    "margin_mode": "isolated",
    "exchange": {
        "name": "binance",
        "pair_whitelist": ["BTC/USDT:USDT", "ETH/USDT:USDT"]
    }
}
```

Futures pairs use `:USDT` suffix (e.g. `BTC/USDT:USDT`).

## Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `max_open_trades` | Max concurrent trades (-1 = unlimited) | Required |
| `stake_amount` | Amount per trade or `"unlimited"` | Required |
| `dry_run` | Simulate trades without real money | `true` |
| `dry_run_wallet` | Starting balance for simulation | `1000` |
| `trading_mode` | `spot` or `futures` | `spot` |
| `margin_mode` | `isolated` or `cross` (futures only) | — |
| `unfilledtimeout.entry` | Minutes before canceling unfilled entry | Required |
| `unfilledtimeout.exit` | Minutes before canceling unfilled exit | Required |

## Strategy Override Parameters

These can be set in either config or strategy (strategy takes lower priority):
`timeframe`, `stoploss`, `minimal_roi`, `trailing_stop`, `trailing_stop_positive`,
`trailing_stop_positive_offset`, `process_only_new_candles`, `use_exit_signal`,
`exit_profit_only`, `ignore_roi_if_entry_signal`, `order_types`, `order_time_in_force`,
`max_open_trades`, `position_adjustment_enable`, `max_entry_position_adjustment`

## Environment Variables

Override config values with `FREQTRADE__` prefix:
```bash
FREQTRADE__EXCHANGE__KEY=<key>
FREQTRADE__EXCHANGE__SECRET=<secret>
FREQTRADE__STAKE_AMOUNT=200
FREQTRADE__EXCHANGE__PAIR_WHITELIST='["BTC/USDT", "ETH/USDT"]'
```

## Multiple Config Files

```bash
freqtrade trade --config config.json --config config-private.json
```

Or in config: `"add_config_files": ["config-private.json"]`

## Dynamic Pairlists

```json
{
    "pairlists": [
        { "method": "VolumePairList", "number_assets": 20, "sort_key": "quoteVolume" },
        { "method": "AgeFilter", "min_days_listed": 10 },
        { "method": "PrecisionFilter" },
        { "method": "PriceFilter", "low_price_ratio": 0.01 }
    ]
}
```
