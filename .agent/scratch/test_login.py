import requests

def test_login():
    url = "http://localhost:5000/api/auth/login"
    data = {
        "email": "test@example.com",
        "password": "password123"
    }
    try:
        response = requests.post(url, json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_login()
