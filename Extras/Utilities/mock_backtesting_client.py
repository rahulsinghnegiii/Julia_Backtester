import msgpack
import requests

url = "http://localhost:5000/backtest"
response = requests.get(url)
print(response.text)

print("")
print("-------------------------------------------------------")
print("")

url = "http://localhost:5000/flow"
response = requests.get(url)
print(msgpack.unpackb(response.content))