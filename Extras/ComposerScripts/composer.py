import datetime
import requests
import pandas as pd
import time
import pytz
import datetime
import json
from scipy.stats import pearsonr

UTC_TIMEZONE = pytz.UTC

def epoch_days_to_date(days: int) -> datetime.date:
    return datetime.datetime.fromtimestamp(days * 24 * 60 * 60, tz=UTC_TIMEZONE).date()


def get_dvm_capital(symphony_id):
    try:
        max_start_date = '2022-07-27'
        max_start_date_backtest = run_backtest_for_period(symphony_id, max_start_date, '2024-05-30')
        print(max_start_date_backtest)
        max_start_date_backtest = dict(sorted(max_start_date_backtest['dvm_capital'].items()))
        return max_start_date_backtest
    except Exception as e:
        print(f"An unexpected error occurred in get_dvm_capital for symphony {symphony_id}: {e}")
        return None

def calculate_returns_from_dvm_capital(dvm_capital):
    try:
        dvm_capital = dict(sorted(dvm_capital.items()))
        dvm_capital = {epoch_days_to_date(int(k)): v for k, v in dvm_capital.items()}
        print(dvm_capital)
        returns = pd.Series(dvm_capital).pct_change().dropna()
        return returns
    except Exception as e:
        print(f"An unexpected error occurred in calculate_returns_from_dvm_capital: {e}")
        return None

def run_backtest(data_raw, id, max_retries=3):
    url = 'https://backtest-api.composer.trade/api/v2/public/symphonies/'+ id + '/backtest'
    headers = {
        'authority': 'backtest-api.composer.trade',
        'accept': 'application/json',
        'accept-language': 'en-US,en;q=0.9',
        'content-type': 'application/transit+json',
        'origin': 'https://app.composer.trade',
        'referer': 'https://app.composer.trade/',
        'sec-ch-ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-site',
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    retries = 0
    while retries < max_retries:
        try:
            response = requests.post(url, headers=headers, data=data_raw)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error executing backtest for id {id}: {e}")
            retries += 1
            if retries < max_retries:
                print(f"Retrying... Attempt {retries}/{max_retries}")
                time.sleep(1)  # Add a small delay before retrying
            else:
                print(f"Maximum retries ({max_retries}) reached. Aborting.")
                return None
        except Exception as e:
            print(f"An unexpected error occurred during backtest for id {id}: {e}")
            return None

def run_backtest_for_period(symphony_id, start_date, end_date):
    try:
        data_raw = '["^ ","~:benchmark_symphonies",[],"~:benchmark_tickers",["SPY"],"~:backtest_version","v2","~:apply_reg_fee",true,"~:apply_taf_fee",true,"~:slippage_percent",0.0005,"~:start_date","' + str(start_date) + '","~:capital",100000,"~end_date","' + str(end_date) + '"]'
        result = run_backtest(data_raw, id=symphony_id)
        print(result)
        if result is not None and 'dvm_capital' in result:
            return {'symphony_id': symphony_id, 'dvm_capital': result['dvm_capital'][str(symphony_id)]}
        else:
            print(f"Backtest for symphony {symphony_id} returned no result")
            return None
    except Exception as e:
        print(f"An unexpected error occurred during backtest for symphony_id {symphony_id}: {e}")
        return None

if __name__ == "__main__":
    symphony_id = "SEXQza2VfiZzdFo8s8zT"
    pd.set_option('display.max_rows', None)
    results = get_dvm_capital(symphony_id)
    # print(results)

    returns = calculate_returns_from_dvm_capital(results)
    print("\n\n\n")
    # print(returns)