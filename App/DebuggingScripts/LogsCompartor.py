import csv
import sys
from decimal import Decimal, ROUND_HALF_UP
import chardet

def detect_encoding(file_path):
    with open(file_path, 'rb') as file:
        raw_data = file.read()
    result = chardet.detect(raw_data)
    return result['encoding']

def read_file_with_encoding(file_path):
    encoding = detect_encoding(file_path)
    try:
        with open(file_path, 'r', encoding=encoding) as txt_file:
            return txt_file.readlines()
    except UnicodeDecodeError:
        print(f"Error: Unable to decode {file_path} with detected encoding {encoding}")
        return []

def compare_log_to_log(first_log_path, second_log_path, output_path):
    first = dict()
    second = dict()

    for line in read_file_with_encoding(first_log_path):
        if 'buying' not in line:
            continue
        line_split = line.strip().split(' ')
        date = line_split[1]
        stock = line_split[4]
        if date not in first:
            first[date] = []
        first[date].append(stock)

    for line in read_file_with_encoding(second_log_path):
        if 'buying' not in line:
            continue
        line_split = line.strip().split(' ')
        date = line_split[1]
        stock = line_split[4]
        if date not in second:
            second[date] = []
        second[date].append(stock)

    # Compare and write output
    with open(output_path, 'w', encoding='utf-8') as output_file:
        same_date_count = 0
        wrong_date_count = 0
        for date, second_stocks in second.items():
            if date in first:
                first_stocks = first[date]
                if len(second_stocks) == 0:
                    continue

                same_date_count += 1
                if set(sorted(second_stocks)) != set(sorted(first_stocks)):
                    wrong_date_count += 1
                    output = f"Date: {date}, {first_log_path}: {set(sorted(first_stocks))} "
                    output += f"{second_log_path}: {set(sorted(second_stocks))} "
                    if len(set(sorted(second_stocks)) - set(sorted(first_stocks))) > 0:
                        output += f"Missing from {first_log_path} stocks: {set(sorted(second_stocks)) - set(sorted(first_stocks))} "
                    if len(set(sorted(first_stocks)) - set(sorted(second_stocks))) > 0:
                        output += f"Extra in {first_log_path} stocks: {set(sorted(first_stocks)) - set(sorted(second_stocks))} "

                    # Calculate percentage difference
                    symmetric_difference = set(second_stocks).symmetric_difference(set(first_stocks))
                    union_stocks = set(second_stocks).union(set(first_stocks))
                    percentage_difference = (len(symmetric_difference) / len(union_stocks) * 100).__round__(2)

                    output += f"Percentage Difference: {percentage_difference}\n"
                    output_file.write(output)
        print(f"Total Same Dates: {same_date_count}, Total Wrong Dates: {wrong_date_count}, Percentage: {(wrong_date_count / same_date_count) * 100}")

first_log_path = "qac-d.log"
second_log_path = "qac.log"
stratName = first_log_path.strip(".log") + "_diff_" + second_log_path.strip(".log")

compare_log_to_log(first_log_path, second_log_path, f"{stratName}_diff_stock.log")