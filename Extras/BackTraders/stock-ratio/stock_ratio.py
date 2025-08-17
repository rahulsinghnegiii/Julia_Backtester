import backtrader as bt
import pandas as pd

df_aapl = pd.read_parquet('../../data/AAPL.parquet')
df_msft = pd.read_parquet('../../data/MSFT.parquet')

# Ensure the index is a DatetimeIndex
if not isinstance(df_aapl.index, pd.DatetimeIndex):
    df_aapl['date'] = pd.to_datetime(df_aapl['date'])
    df_aapl.set_index('date', inplace=True)

if not isinstance(df_msft.index, pd.DatetimeIndex):
    df_msft['date'] = pd.to_datetime(df_msft['date'])
    df_msft.set_index('date', inplace=True)
# Print date ranges
print(f"AAPL data range: {df_aapl.index.min()} to {df_aapl.index.max()}")
print(f"MSFT data range: {df_msft.index.min()} to {df_msft.index.max()}")

class PrintClose(bt.Strategy):
    def __init__(self):
        self.dataclose_aapl = self.datas[0].close
        self.dataclose_msft = self.datas[1].close
    
    def log(self, txt, dt=None):
        dt = dt or self.datas[0].datetime.date(0)
        print(f'{dt.isoformat()} {txt}')

    def next(self):
        if len(self.dataclose_aapl) > 0 and len(self.dataclose_msft) > 0:
            stock_ratio = self.dataclose_aapl[0] / self.dataclose_msft[0]
            self.log(f'AAPL Close: {self.dataclose_aapl[0]}, MSFT Close: {self.dataclose_msft[0]}, Ratio: {stock_ratio}')
        else:
            self.log('Insufficient data for both stocks')

cerebro = bt.Cerebro()

# Create data feeds
df_parsed_aapl = bt.feeds.PandasData(dataname=df_aapl, datetime=None)
df_parsed_msft = bt.feeds.PandasData(dataname=df_msft, datetime=None)

# Add data feeds to Cerebro
cerebro.adddata(df_parsed_aapl)
cerebro.adddata(df_parsed_msft)

# Add strategy to Cerebro
cerebro.addstrategy(PrintClose)

# Run the backtest
cerebro.run()