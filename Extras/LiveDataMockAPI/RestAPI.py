from flask import Flask, jsonify
from datetime import datetime
import random

app = Flask(__name__)

@app.route('/get_live_data', methods=['GET'])
def get_stock_data():
    # Get today's date and format it
    today = datetime.now().strftime('%Y-%m-%d')
    
    # Generate random adjusted close value
    adjusted_close = round(random.uniform(200, 600), 2)
    
    # Create response dictionary
    response = {
        "data": 
        {
            "date": today,
            "adjusted_close": adjusted_close
        }
    }
    
    return jsonify(response)

if __name__ == '__main__':
    app.run(debug=True, port=4001)
