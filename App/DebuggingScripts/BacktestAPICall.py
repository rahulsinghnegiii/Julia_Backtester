import sys
import os
import pandas as pd
import msgpack
import json
import requests
import concurrent.futures
import uuid
import time

# Add the parent directory of the 'stock_database' package to sys.path
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

print("Live Execution")

try:
    with open("../Tests/TestsJSON/DevJSON/test1.json", "r", encoding="utf-8") as file:
        json_data = file.read()
    # Parse the JSON data if needed
    data_to_post = json_data
except UnicodeDecodeError:
    print("Error: Unable to decode the file with UTF-8 encoding.")
except json.JSONDecodeError:
    print("Error: The file does not contain valid JSON data.")
except FileNotFoundError:
    print("Error: File was not found.")
except Exception as e:
    print(f"An unexpected error occurred: {str(e)}")

# ----------------------------------- Data --------------------------------------#

end_date = "2024-12-10"
period = "5000"


url = "http://localhost:5004/backtest"
headers = {
    "Content-Type": "application/json"
}

# # --------------------------------------------------------------------------------#

# ------------------------------ Helper Functions --------------------------------#

def generate_hash():
    return str(uuid.uuid4())

def make_request(hash_value):
    try:
        print(f"Making request with hash: {hash_value}")
        start_time = time.time()
        response = requests.post(
            url,
            data=json.dumps({
                "json": data_to_post,
                "period": period,
                "hash": "hash_value",
                "end_date": end_date,
                "live_execution": True
            }),
            headers=headers
        )
        end_time = time.time()
        duration = end_time - start_time
        return response.text, duration
    except Exception as e:
        return f"Error: {str(e)}", None

# ------------------------------ Concurrent Requests -----------------------------#

def run_concurrent_requests(num_requests):
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_requests) as executor:
        futures = [executor.submit(make_request, generate_hash()) for _ in range(num_requests)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    return results

# ---------------------------- Execute Concurrent Requests -----------------------#

num_requests = 1 # Adjust this number to change the number of concurrent requests
results = run_concurrent_requests(num_requests)

# ---------------------------- Process and Print Results -------------------------#

for i, (result, duration) in enumerate(results, 1):
    print(f"Result {i}:")
    if duration is not None:
        print(f"Time taken: {duration:.2f} seconds")
    print("-" * 50)



# ------------------------------ Flow Request --------------------------------#

# url = "https://dev.algozen.io/api/v2/backtest/flow"
# url = "http://localhost:5004/flow"
# response = requests.post(url, data=json.dumps({"hash":"hash_value_test10", "end_date": end_date}),
#                             headers=headers)

# # # Use a streaming unpacker to handle the msgpacked response
# unpacker = msgpack.Unpacker()
# unpacker.feed(response.content)

# # Iterate over unpacked objects
# for unpacked_data in unpacker:
#     print(unpacked_data)