import requests

BASE_URL = "https://api.example.com/v1"

def get_users():
    response = requests.get(BASE_URL + "/users")
    return response.json()

def create_user(name, email):
    response = requests.post(BASE_URL + "/users", json={"name": name, "email": email})
    return response.json()
