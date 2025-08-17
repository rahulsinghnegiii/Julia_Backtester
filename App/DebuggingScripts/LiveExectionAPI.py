import json
import requests
from supabase import create_client
import uuid
import random
import time
from datetime import datetime

# Supabase configuration
supabase_url = "https://supa.dev.algozen.io"
supabase_key = ""

supabase = create_client(supabase_url, supabase_key)

# List of strategy IDs to test
strategy_ids = [196, 222, 227, 228, 237, 248, 249]
url = "http://localhost:5004/backtest"
headers = {
    "Content-Type": "application/json"
}

def get_strategy_json(strategy_id):
    try:
        response = supabase.table('strategy').select('*, brokerage(*)').eq('strategy_id', strategy_id).execute()
        strategies = response.data if response.data else []
        return strategies[0]['strategy_json'] if strategies else None
    except Exception as e:
        return None

def make_request(strategy_json, hash_value):
    try:
        response = requests.post(
            url,
            data=json.dumps({
                "json": strategy_json,
                "period": "5000",
                "hash": hash_value,
                "end_date": "2024-09-30",
                "live_execution": True
            }),
            headers=headers
        )
        return response.text
    except Exception as e:
        return f"Error: {str(e)}"

def log_result(file_handle, strategy_id, time_taken, result):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] Strategy ID: {strategy_id}, Time: {time_taken:.2f}s, Result: {result}\n"
    file_handle.write(log_entry)
    file_handle.flush()  # Ensure immediate writing to file

# Run load test
total_tests = 200

with open('results.log', 'w') as log_file:
    log_file.write(f"Starting load test with {total_tests} iterations\n")
    
    for i in range(total_tests):
        # Randomly select a strategy ID
        strategy_id = random.choice(strategy_ids)
        
        # Get strategy JSON
        start_time = time.time()
        strategy_json = get_strategy_json(strategy_id)
        
        if strategy_json:
            # Generate a unique hash
            hash_value = str(uuid.uuid4())
            
            # Make the request
            result = make_request(strategy_json, hash_value)
            
            # Calculate time taken
            time_taken = time.time() - start_time
            
            # Log the result
            log_result(log_file, strategy_id, time_taken, result)
            
            # Print progress
            print(f"Completed test {i+1}/{total_tests} - Strategy ID: {strategy_id}, Time: {time_taken:.2f}s")
            
            # Add a small delay to prevent overwhelming the server
            time.sleep(0.1)
        else:
            log_result(log_file, strategy_id, 0, "Failed to fetch strategy JSON")
            print(f"Failed to fetch strategy {strategy_id} - Skipping")

    # Log summary
    log_file.write("\nLoad test completed\n")

print("Load test completed. Results saved to results.log")