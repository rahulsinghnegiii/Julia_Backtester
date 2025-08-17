import json

# Load JSON from file
file_path = '../Strategies/blob.json'
with open(file_path, 'r') as file:
    data = json.load(file)

tickers = []

# Traverse the JSON data and collect values of "source" and "symbol" keys
def traverse(data):
    if isinstance(data, dict):
        for key, value in data.items():
            if key == "symbol" or key == "source":
                if value not in tickers:
                    tickers.append(value)
            else:
                traverse(value)
    elif isinstance(data, list):
        for item in data:
            traverse(item)

# Start traversal from the root of the JSON object
traverse(data)

# Print the collected values for "symbol" and "source" keys
print("Tickers in JSON:", tickers)
