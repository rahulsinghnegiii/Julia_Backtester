# Code to create a REST API server that serves a JSON file with authentication

from flask import Flask, request, Response, jsonify
import base64

app = Flask(__name__)

# Credentials
USERNAME = "fsdev87"
PASSWORD = "1234"

# Load the JSON file
def load_json_file():
    with open("data.json", "r") as f:
        return f.read()

# Authentication check
def check_auth(auth):
    try:
        # Decode Base64 credentials
        credentials = base64.b64decode(auth.split(" ")[1]).decode("utf-8")
        username, password = credentials.split(":")
        return username == USERNAME and password == PASSWORD
    except Exception:
        return False

# Route for the JSON file
@app.route("/")
def serve_json():
    auth_header = request.headers.get("Authorization")
    
    # Check if Authorization header is provided
    if not auth_header:
        return Response(
            "Unauthorized: Please provide credentials",
            401,
            {"WWW-Authenticate": 'Basic realm="Access to localhost"'}
        )
    
    # Check credentials
    if check_auth(auth_header):
        json_data = load_json_file()
        return Response(json_data, 200, content_type="application/json")
    else:
        return Response(
            "Forbidden: Invalid credentials",
            403
        )

# Run the server
if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
