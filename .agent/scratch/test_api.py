import requests

def test_register():
    url = "http://localhost:5000/api/auth/register"
    data = {
        "name": "Test User",
        "email": "test@example.com",
        "password": "password123",
        "role": "seeker"
    }
    try:
        response = requests.post(url, json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_register()
