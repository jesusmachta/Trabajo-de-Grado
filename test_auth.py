import requests
import json

# Create a test user
signup_data = {
    'email': 'test@example.com',
    'password': 'password123',
    'full_name': 'Test User',
    'role': 'user'
}

# Replace with your actual endpoint URL
base_url = 'http://localhost:8000/api'

try:
    # Try to create a new user
    print('Attempting to register a new user...')
    response = requests.post(f'{base_url}/signup', json=signup_data)
    print(f'Status code: {response.status_code}')
    print(f'Response: {response.text}')
    
    if response.status_code == 200 or response.status_code == 201:
        print('User created successfully! Now testing login...')
        
        # Try to log in with the created user
        login_data = {
            'email': 'test@example.com',
            'password': 'password123'
        }
        
        login_response = requests.post(f'{base_url}/login', json=login_data)
        print(f'Login status code: {login_response.status_code}')
        print(f'Login response: {login_response.text}')
        
        if login_response.status_code == 200:
            print('Login successful!')
            token = login_response.json().get('access_token')
            print(f'Access token: {token[:15]}...')
    else:
        print('Failed to create user')
except Exception as e:
    print(f'Error: {e}') 