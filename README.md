# Setting up the Repository
---
# Setting up Parquets and Dependencies

## Run the Python script to automatically setup the parquets
- Run the python script in the Scripts/ProjectSetup Folder "SetupRepo.py" using the following command "python SetupRepo.py". The script will download the Stock Data Parquets.
---
## Run the julia Script to automatically setup the dependencies
- Run the julia script in the Scripts/ProjectSetup Folder "SetupDependencies.jl" using the following command "julia SetupDependencies.jl". The script will install all the dependencies required for the project.

## Step 1: Install JET
- Install JET package globally using Julia REPL:<br>
  using Pkg; Pkg.add("JET")<br> 

## Step 2: Install JuliaFormatter
- Install JuliaFormatter package globally using Julia REPL:<br>
  using Pkg; Pkg.add("JuliaFormatter")<br>

## Step 3: Run the Python script to automatically setup the hooks
- Run the python script "SetupHooks.py" using the following command "python SetupHooks.py". The script will check for existing presence of hooks. If the hooks are not present then the script will automatically create them.

## All Done with Hooks:
### The JET script is configured to run automatically when you push anything to Github. It will display an error message if your code has issues and will not allow you to push the code unless the issues are fixed<br>
### The formatter script is configured to run automatically when you commit anything to Github. It will automatically format all files staged.<br>

## Manual verification
### If your jet test is failing and you want to know where exactly the issue lies. Just run the 'git push' command through CMD and complete JET error log will appear helping you to diagnose the issue. 
---
## All Done with the Setup:
### You should now be able to run the code in the repository without facing any errors.<br>
---

# Sample CURL Commands for Indicators Endpoints

```

curl -X GET "http://dev.algozen.io:5004/get_deltas_start_end?ticker=AAPL&start_date=2023-1-10&end_date=2023-1-13"

curl -X GET "http://dev.algozen.io:5004/get_stock_data_start_end?ticker=AAPL&start_date=2023-1-10&end_date=2023-2-10"

curl -X GET "http://dev.algozen.io:5004/get_stock_data_period?ticker=AAPL&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/get_stock_data_period_full?ticker=AAPL&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/get_trading_days?ticker=AAPL&start_date=2023-10-10&end_date=2023-10-20"

curl -X GET "http://dev.algozen.io:5004/rsi?ticker=AAPL&length=1500&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/ema?ticker=AAPL&length=1500&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/sma?ticker=AAPL&length=1500&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/sma_returns?ticker=AAPL&length=1500&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/sd_returns?ticker=AAPL&length=1500&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/sd?ticker=AAPL&length=1500&period=14&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/max_drawdown?ticker=AAPL&period=5&end_date=2023-10-10&length=50"

curl -X GET "http://dev.algozen.io:5004/cumulative_return?ticker=AAPL&length=1500&period=2&end_date=2023-10-10"

curl -X GET "http://dev.algozen.io:5004/market_cap?ticker=AAPL&date=2023-10-10&period=5"

```

## Sample CURL Commands for Backtest Endpoints
- **Backtest:**
  - curl -X POST -H "Content-Type: application/json" -d '{"json": "data_to_post", "period": period, "end_date": end_date}' http://localhost:5004/backtest
  - example call (python): <br>
    json_data = open("simpleQLD.json").read() <br>
    data_to_post = json.loads(json_data) <br>
    end_date = "2024-05-31"
    period = "500"
    hash = "hashvalue"

    url = "http://localhost:5004/backtest" <br>
    headers = { <br>
      "Content-Type": "application/json" <br>
    } <br>

    response = requests.post(url, data=json.dumps({"json": data_to_post, "period": period, "hash": hash, "end_date": end_date}),
                                headers=headers) <br>  
    print(response.text)
  - example response: <br>
```    
    {
      "returns": [-0.049549185, 0.007948038, 0.012167203, 0.017172774, 0.0031706814],
      "dates": ["2024-05-25", "2024-05-26", "2024-05-27", "2024-05-28", "2024-05-29"]
    }
```
---

### Documentation of Inverse Volatility and Weighting
# Inverse Volatility Calculation
# Overview
Inverse volatility weighting is a strategy where each asset in a portfolio is assigned a weight inversely proportional to its volatility. This means assets with lower volatility get a higher weight. The rationale behind this approach is to minimize the portfolio's overall volatility, under the assumption that lower volatility assets present lower risks.

# Calculation Steps
* Daily Returns Calculation: For each stock in the stock list, calculate the daily returns. This is the percentage change in price from one day to the next.
* Volatility Calculation: Calculate the standard deviation of the daily returns for each stock over the lookback period. This standard deviation is a measure of volatility.
* Inverse Volatility: Calculate the inverse of the volatility for each stock. This is simply (1 / std).
* Normalization: Sum all the inverse volatilities to get a total. Then, for each stock, divide its inverse volatility by the total. This ensures that the sum of weights across all stocks equals 1.
# calculate_inverse_volatility_for_stocks
This function orchestrates the calculation by iterating over each stock, calculating its inverse volatility, and then normalizing these values across all stocks in the list for each date within the specified period.

### Weighting Calculation
# Overview
The weighting endpoint is designed to calculate the weights of different components (referred to as branches in the code) of a portfolio for each date based on provided values. This could be used, for example, to adjust the allocation of assets in a portfolio over time based on some criteria or data.

# Calculation Steps
* Aggregate Values by Date: For each date, sum the standard deviation values for all branches (except the lookback period). This gives a total value for the portfolio on each date.
* Calculate Weights: For each branch and each date, divide the branch's value by the total value for that date. This gives the weight of each branch on that date, representing its proportion of the total portfolio value.
# calculate_weights
This function takes the input data, which is structured as an array of branches, with each branch being an array of date-value pairs. It first aggregates the values by date across all branches. Then, for each date, it calculates the weight of each branch by dividing the branch's value by the total value for that date.
