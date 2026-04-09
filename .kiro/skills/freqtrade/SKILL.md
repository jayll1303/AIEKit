---
name: freqtrade
description: "Develop crypto trading strategies with Freqtrade. Use when creating IStrategy classes, writing populate_indicators/entry/exit, running backtesting/hyperopt, configuring bot JSON, implementing callbacks (custom_stoploss, DCA, leverage), or downloading OHLCV data."
---

# Freqtrade Development Skill

Build, backtest, and optimize crypto trading strategies with the Freqtrade Python framework.

## Scope

Handles: strategy development (IStrategy), backtesting, hyperopt, data download, bot configuration, callbacks, informative pairs, indicator libraries (ta-lib, pandas-ta, technical).
Does NOT handle:
- FreqAI / ML model training (→ separate FreqAI skill)
- Exchange API setup / account management
- Docker/server deployment of live bots
- Portfolio management across multiple bots

## When to Use

- Creating or modifying an IStrategy subclass
- Running backtests or hyperopt optimization
- Configuring bot JSON (spot or futures)
- Implementing callbacks (custom_stoploss, custom_exit, DCA, leverage)
- Downloading OHLCV data for backtesting
- Setting up informative pairs / multi-timeframe strategies
- Debugging lookahead bias or startup_candle_count issues

## Strategy Type Decision Table

| Goal | Approach | Key Config |
|---|---|---|
| Simple spot long-only | Basic IStrategy, `can_short=False` | `trading_mode: spot` |
| Futures with shorts | IStrategy, `can_short=True` | `trading_mode: futures`, `margin_mode: isolated` |
| DCA / position adjustment | `adjust_trade_position()` callback | `position_adjustment_enable: true` |
| Dynamic stoploss | `custom_stoploss()` callback | `use_custom_stoploss: true` |
| Multi-timeframe | `@informative('1h')` decorator | Set `startup_candle_count` for longest TF |
| Parameter optimization | Hyperopt with IntParameter/DecimalParameter | `--spaces buy sell roi stoploss` |

## Quick Start: New Strategy

1. Generate template:
```bash
freqtrade new-strategy --strategy MyStrategy --template advanced
```
2. Edit `user_data/strategies/MyStrategy.py` — set `INTERFACE_VERSION = 3`, `timeframe`, `stoploss`, `minimal_roi`
3. Download data:
```bash
freqtrade download-data --config config.json --timeframes 5m 1h --days 30
```
**Validate:** Check `user_data/data/<exchange>/` has `.feather` files.

4. Backtest:
```bash
freqtrade backtesting --strategy MyStrategy --timerange 20240101-20240601
```
**Validate:** Output shows trade count > 0, no lookahead warnings.

5. Optimize:
```bash
freqtrade hyperopt --strategy MyStrategy --hyperopt-loss SharpeHyperOptLossDaily --spaces all -e 500
```
**Validate:** Best result shows positive Sharpe ratio.

## Key Rules

- `INTERFACE_VERSION = 3` (current)
- Always return dataframe from `populate_*` without removing OHLCV columns
- Use vectorized pandas ops, NEVER loops in `populate_*`
- Use `df.shift()` not `df.iloc[-1]` in `populate_*` (avoid lookahead)
- `startup_candle_count` = max indicator lookback period
- Callbacks CAN use `.iloc[-1]` via `dp.get_analyzed_dataframe()`
- Volume > 0 guard on all entry signals
- Stoploss is negative ratio (`-0.10` = 10% loss)
- `minimal_roi` keys = minutes as strings, values = profit ratios

## Troubleshooting

```
Backtest shows 0 trades?
├─ Check timerange has data: freqtrade list-data --show-timerange
├─ Check pair_whitelist matches downloaded pairs
├─ Check entry conditions — too strict? Test with relaxed params
└─ Check startup_candle_count not eating entire timerange

Hyperopt not improving?
├─ Increase epochs (-e 1000 --early-stop 100)
├─ Try different loss function (SharpeHyperOptLossDaily vs CalmarHyperOptLoss)
├─ Narrow search spaces (fewer parameters)
└─ Check if strategy has hyperoptable parameters defined

Lookahead bias detected?
├─ Run: freqtrade lookahead-analysis --strategy MyStrategy
├─ Check populate_* for .iloc[-1] usage → replace with .shift()
├─ Check for future data in informative pairs
└─ Ensure startup_candle_count covers all indicator periods

Bot crashes on live/dry-run?
├─ Validate config: freqtrade show-config --config config.json
├─ Check exchange API keys and permissions
├─ Check pair format (futures needs :USDT suffix)
└─ Check unfilledtimeout settings in config
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "iloc[-1] is fine in populate_*" | Causes lookahead bias — use shift() or vectorized ops only |
| "startup_candle_count = 20 is enough" | Must match longest indicator period (EMA200 → ≥200) |
| "Skip volume > 0 guard" | Empty candles cause false signals — always guard |
| "Test on full date range" | Split data: train on 70%, validate on 30% to avoid overfitting |
| "Hyperopt with all spaces at once" | Start with buy/sell, then roi/stoploss separately for better convergence |
| "Same config for spot and futures" | Futures needs trading_mode, margin_mode, :USDT pair suffix |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to install Python deps, resolve version conflicts | python-ml-deps | Handles uv, CUDA deps, version resolution |
| Need to set up pyproject.toml, ruff, pytest for strategy project | python-project-setup | Project scaffolding and tooling |
| Need to containerize bot for deployment | docker-gpu-setup | Dockerfile patterns for GPU workloads |
| Need to track backtest/hyperopt experiments systematically | experiment-tracking | MLflow/W&B metric logging and comparison |

## References

Load as needed:
- [Strategy Development](references/strategy-development.md) — Templates, indicators, hyperopt params
  **Load when:** Creating or modifying IStrategy classes
- [Callbacks Advanced](references/callbacks-advanced.md) — All callback signatures, DataProvider, informative pairs
  **Load when:** Implementing custom_stoploss, custom_exit, DCA, or informative pairs
- [Callback Examples](references/callback-examples.md) — Copy-paste callback implementations
  **Load when:** Need working code for specific callbacks
- [CLI Commands](references/cli-commands.md) — Data download, backtesting commands
  **Load when:** Running backtest or downloading data
- [Hyperopt & Utils](references/cli-hyperopt-utils.md) — Hyperopt, strategy management, plotting
  **Load when:** Optimizing parameters or validating strategy
- [Configuration](references/configuration.md) — Bot JSON config, futures setup, pairlists, env vars
  **Load when:** Setting up or modifying bot configuration
