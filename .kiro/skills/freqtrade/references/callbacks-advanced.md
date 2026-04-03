# Strategy Callbacks & Advanced Patterns

## Available Callbacks

| Callback | When Called | Use Case |
|----------|-----------|----------|
| `bot_start()` | Once on strategy load | One-time setup |
| `bot_loop_start()` | Every iteration | Pair-independent tasks |
| `custom_stake_amount()` | Before entering trade | Dynamic position sizing |
| `custom_exit()` | Every iteration for open trades | Custom exit conditions |
| `custom_stoploss()` | Every iteration for open trades | Dynamic stoploss |
| `custom_roi()` | Every iteration for open trades | Dynamic ROI threshold |
| `custom_entry_price()` / `custom_exit_price()` | When placing order | Custom pricing |
| `confirm_trade_entry()` / `confirm_trade_exit()` | Before order | Reject/confirm |
| `adjust_trade_position()` | Every iteration for open trades | DCA / position adjustment |
| `leverage()` | Before entering futures trade | Set leverage per trade |
| `order_filled()` | After order fills | Post-fill actions |

For stoploss/exit callback examples, see `references/callback-examples.md`.

## DataProvider Access (in callbacks only, NOT populate_*)

```python
dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
last_candle = dataframe.iloc[-1].squeeze()
```

## Informative Pairs

```python
# Decorator approach (recommended):
@informative('1h')
def populate_indicators_1h(self, dataframe, metadata):
    dataframe['rsi'] = ta.RSI(dataframe, timeperiod=14)
    return dataframe
# Access as: dataframe['rsi_1h']

# Manual approach:
def informative_pairs(self):
    return [("BTC/USDT", "1h"), ("ETH/USDT", "15m")]
# Access via: self.dp.get_pair_dataframe("BTC/USDT", "1h")
```

## Persistent Trade Data Storage

```python
trade.set_custom_data(key='my_key', value='my_value')
val = trade.get_custom_data(key='my_key', default=0)
```

## Stoploss Helpers

```python
from freqtrade.strategy import stoploss_from_open, stoploss_from_absolute
# Relative to open price (7% above open):
stoploss_from_open(0.07, current_profit, is_short=trade.is_short, leverage=trade.leverage)
# From absolute price:
stoploss_from_absolute(price, current_rate, is_short=trade.is_short, leverage=trade.leverage)
```

## Protections (Hyperoptable)

```python
@property
def protections(self):
    return [
        {"method": "CooldownPeriod", "stop_duration_candles": self.cooldown.value},
        {"method": "StoplossGuard", "lookback_period_candles": 72,
         "trade_limit": 4, "stop_duration_candles": self.stop_dur.value}
    ]
```
