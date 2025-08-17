import csv
import sys

# Define stocks dictionary
stocks = {
    2: 'USD',
    3: 'MSFT',
    4: 'NVDA',
    5: 'AAPL'
}

# 8 aug 2004 -- 30 may 2024
indicators = ['cr', 'ema', 'max_dd', 'rsi', 'sma_price', 'sma_return', 'std_price', 'std_return' ]

for indicator in indicators:

    print(f"Processing {indicator}...")
    composer = dict()
    our = dict()

    # Read the CSV file and populate the 'composer' dictionary
    with open(f"./csvs/{indicator}.csv", mode='r', encoding='utf-8-sig') as csv_file:
        print(f"Reading {indicator}.csv...")
        csv_reader = csv.reader(csv_file)
        for line in csv_reader:
            date = line[0]
            composer[date] = {}
            for idx in range(2, 6):  # indices 2 to 5
                if line[idx] != '-':
                    value = line[idx]
                    if value.endswith('%'):
                        value = float(value[:-1])
                    composer[date][stocks[idx]] = value

    # Read the TXT file and populate the 'our' dictionary
    try:
        with open(f"./logs/{indicator}.log", 'r', encoding='utf-8') as txt_file:
            print(f"Reading {indicator}.log...")
            for line in txt_file:
                if 'stocks' in line:
                    continue
                line_split = line.strip().split(' ')
                our[line_split[1]] = line_split[4]
    except UnicodeDecodeError:
        # If UTF-8 fails, try UTF-16
        with open(f"./logs/{indicator}.log", 'r', encoding='utf-16') as txt_file:
            for line in txt_file:
                if 'stocks' in line:
                    continue
                line_split = line.strip().split(' ')
                our[line_split[1]] = line_split[4]

    with open(f"./changes/{indicator}.diff", 'w') as diff_file:
        # Compare the 'composer' and 'our' dictionaries
        print(f"Writing into {indicator}.diff...")
        for date, stocks_dict in composer.items():
            if date in our:
                our_stock = our[date]
                
                # Check if there's a mismatch
                if our_stock not in stocks_dict:
                    output = f"Date: {date}, Our: {our_stock} "
                    output += "Composer: "
                    for stock, value in stocks_dict.items():
                        output += f"{stock}: {value}, "
                    
                    # Remove the trailing comma and space
                    output = output.rstrip(", ")
                    
                    diff_file.write(output + "\n")