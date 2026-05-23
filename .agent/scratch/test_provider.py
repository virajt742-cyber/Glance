import requests

def test_register_provider():
    url = "http://localhost:5000/api/auth/register"
    data = {
        "name": "Test Provider",
        "email": "provider@example.com",
        "password": "password123",
        "role": "provider"
    }
    try:
        response = requests.post(url, json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_register_provider()
