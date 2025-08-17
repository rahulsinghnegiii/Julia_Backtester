import csv
import sys

tickers_list = [
    "UPRO","TECS","EEM","VXX","SOXL","TMF","EPI","EWZ","PUI","CURE","$USD","UUP","SHY","SPXL","ERX","SPXU","TECL","SPXS","TQQQ","EFA","SOXS","QLD","DIG","GLD","TLT","PDBC","TMV","IYK","BIL","USD","SQQQ","AGG","MVV"
]

if len(sys.argv) == 0:
    print("Please the id of symphony as python3 main.py <id>")
    exit(1)



stocks = {i+2: ticker for i, ticker in enumerate(tickers_list)}
start_range = 2
end_range = max(stocks.keys()) + 1
def calculate_percentage_diff(csv_path, our_path, output_path):
  our = dict()
  composer = dict()

  with open(csv_path, mode='r') as csv_file:
      csv_reader = csv.reader(csv_file)
      next(csv_reader)
      for line in csv_reader:
          date = line[0]
          if date not in composer:
              composer[date] = dict()
          for idx in range(start_range, end_range):
              if line[idx] != '-' and stocks[idx] != '$USD':
                  stock = stocks[idx]
                  if stock not in composer[date]:
                      composer[date][stock] = 0.0
                  composer[date][stock] += float(line[idx].strip('%'))

  with open(our_path, mode='r') as text_file:
      for line in text_file:
          line_split = line.strip().split(' ')
          date = line_split[1]
          if date not in our:
              our[date] = dict()
          stock = line_split[4]
          if stock not in our[date]:
              our[date][stock] = 0.0
          our[date][stock] += float(line_split[3].strip('%'))

  with open(output_path, mode='w') as output_file:
    for date, composer_stocks in composer.items():
        if date in our:
            our_stocks = our[date]
            if composer_stocks != our_stocks:
              output_file.write(f"Date: {date}, Composer: {composer_stocks}, Our: {our_stocks}\n")
        

def calculate_stock_diff_only(csv_path, our_path, output_path):
    composer = dict()
    our = dict()

    with open(csv_path, mode='r', encoding='utf-8-sig') as csv_file:
        csv_reader = csv.reader(csv_file)
        for line in csv_reader:
            date = line[0]
            composer[date] = []
            for idx in range(start_range, end_range):
                if line[idx] != '-' and stocks[idx] != '$USD':
                    composer[date].append(stocks[idx])

    with open(our_path, 'r', encoding='utf-8') as txt_file:
        for line in txt_file:
            if 'stocks' in line:
                continue
            line_split = line.strip().split(' ')
            date = line_split[1]
            stock = line_split[4]
            if date not in our:
                our[date] = []
            our[date].append(stock)
    with open(output_path, 'w') as output_file:
        for date, composer_stocks in composer.items():
            if date in our:
                our_stocks = our[date]
                
                if set(sorted(composer_stocks)) != set(sorted(our_stocks)):
                    output = f"Date: {date}, Our: {set(sorted(our_stocks))} "
                    output += f"Composer: {set(sorted(composer_stocks))} "
                    if len(set(sorted(composer_stocks)) - set(sorted(our_stocks))) > 0:
                        output += f"Missing from our stocks: {set(sorted(composer_stocks)) - set(sorted(our_stocks))} "
                    if len(set(sorted(our_stocks)) - set(sorted(composer_stocks))) > 0:
                        output += f"Extra in our stocks: {set(sorted(our_stocks)) - set(sorted(composer_stocks))} "

                    symmetric_difference = set(composer_stocks).symmetric_difference(set(our_stocks))
                    union_stocks = set(composer_stocks).union(set(our_stocks))
                    percentage_difference = (len(symmetric_difference) / len(union_stocks) * 100).__round__(2)

                    output += f"Percentage Difference: {percentage_difference}\n"
                    output_file.write(output)

calculate_stock_diff_only('csv.csv', 'message.txt', f"{sys.argv[1]}_diff_stock.log")
calculate_percentage_diff('csv.csv', 'message.txt', f"{sys.argv[1]}_diff_percentage.log")
