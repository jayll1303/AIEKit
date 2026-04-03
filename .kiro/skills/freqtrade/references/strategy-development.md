# Strategy Development

## Minimal Strategy Template

```python
from freqtrade.strategy import IStrategy, IntParameter, DecimalParameter, BooleanParameter, CategoricalParameter
from pandas import DataFrame
import talib.abstract as ta
import freqtrade.vendor.qtpylib.indicators as qtpylib

class MyStrategy(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = '5m'
    can_short = False
    stoploss = -0.10
    startup_candle_count = 200
    minimal_roi = {"0": 0.04, "30": 0.02, "60": 0.01, "120": 0}

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=14)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe['rsi'] < 30) & (dataframe['volume'] > 0),
            ['enter_long', 'enter_tag']] = (1, 'rsi_oversold')
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe['rsi'] > 70) & (dataframe['volume'] > 0),
            ['exit_long', 'exit_tag']] = (1, 'rsi_overbought')
        return dataframe
```

## Entry/Exit Signal Columns

| Column | Purpose |
|--------|---------|
| `enter_long` | 1 to open long |
| `enter_short` | 1 to open short (requires `can_short = True`) |
| `exit_long` | 1 to close long |
| `exit_short` | 1 to close short |
| `enter_tag` | String tag for entry reason |
| `exit_tag` | String tag for exit reason |

## Indicator Libraries

- `talib.abstract as ta` — TA-Lib (RSI, MACD, BBANDS, EMA, SMA, etc.)
- `pandas_ta` — pandas-ta library
- `technical` — freqtrade's technical library
- `qtpylib.indicators` — helper functions (crossed_above, crossed_below, etc.)

## Informative Pairs (Higher Timeframes)

```python
from freqtrade.strategy import informative

class MyStrategy(IStrategy):
    @informative('1h')
    def populate_indicators_1h(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=14)
        return dataframe
    # Access in main as: dataframe['rsi_1h']
```

Manual approach via `informative_pairs()` + DataProvider — see `callbacks-advanced.md`.

## Hyperopt Parameters

```python
class MyStrategy(IStrategy):
    buy_rsi = IntParameter(20, 40, default=30, space="buy")
    buy_adx = DecimalParameter(20, 40, decimals=1, default=30.1, space="buy")
    buy_enabled = BooleanParameter(default=True, space="buy")
    buy_trigger = CategoricalParameter(["bb_lower", "macd_cross"], default="bb_lower", space="buy")

    def populate_entry_trend(self, dataframe, metadata):
        if self.buy_enabled.value:
            dataframe.loc[dataframe['rsi'] < self.buy_rsi.value, 'enter_long'] = 1
        return dataframe
```

For `populate_indicators` with hyperopt, use `.range` to pre-calculate all values:
```python
for val in self.buy_rsi.range:
    dataframe[f'rsi_{val}'] = ta.RSI(dataframe, timeperiod=val)
```

## Common Mistakes

- Using `df.iloc[-1]` in populate_* methods (causes lookahead bias)
- Not setting `startup_candle_count` high enough
- Forgetting `volume > 0` guard
- Using loops instead of vectorized operations
- Modifying/removing OHLCV columns from dataframe
