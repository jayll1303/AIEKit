# Hyperopt & Utility Commands

## Hyperopt (Parameter Optimization)

```bash
# Full optimization
freqtrade hyperopt --strategy MyStrategy --hyperopt-loss SharpeHyperOptLossDaily \
  --spaces all -e 500 --timerange 20240101-20240601

# Optimize specific spaces
freqtrade hyperopt --strategy MyStrategy --hyperopt-loss SharpeHyperOptLossDaily \
  --spaces buy sell -e 300

# ROI and stoploss only
freqtrade hyperopt --strategy MyStrategy --hyperopt-loss SharpeHyperOptLossDaily \
  --spaces roi stoploss trailing -e 200

# With early stopping
freqtrade hyperopt --strategy MyStrategy --hyperopt-loss SharpeHyperOptLossDaily \
  -e 1000 --early-stop 100

# View results
freqtrade hyperopt-list --profitable --min-trades 50
freqtrade hyperopt-show --best
```

Loss functions: `SharpeHyperOptLossDaily`, `SortinoHyperOptLossDaily`, `MaxDrawDownHyperOptLoss`,
`CalmarHyperOptLoss`, `ProfitDrawDownHyperOptLoss`, `MultiMetricHyperOptLoss`

Spaces: `all`, `buy`, `sell`, `roi`, `stoploss`, `trailing`, `trades`, `protection`, `default`

## Strategy Management

```bash
freqtrade new-strategy --strategy MyNewStrategy
freqtrade new-strategy --strategy MyNewStrategy --template advanced
freqtrade list-strategies

# Validate strategy
freqtrade lookahead-analysis --strategy MyStrategy --timerange 20240101-20240301
freqtrade recursive-analysis --strategy MyStrategy --timerange 20240101-20240301
```

## Trading

```bash
# Dry run
freqtrade trade --strategy MyStrategy --config config.json

# Live (dry_run: false in config)
freqtrade trade --strategy MyStrategy --config config.json --config config-private.json
```

## Utilities

```bash
freqtrade new-config --config user_data/config.json
freqtrade show-config --config config.json
freqtrade list-exchanges
freqtrade list-pairs --exchange binance --quote USDT
freqtrade list-timeframes --exchange binance
freqtrade plot-dataframe --strategy MyStrategy --timerange 20240101-20240201
freqtrade plot-profit --strategy MyStrategy
```
