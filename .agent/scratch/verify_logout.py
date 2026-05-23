import os
import sys
from flask_jwt_extended import create_access_token

# Add project root to path
sys.path.append(os.getcwd())

from app import create_app
from app.extensions import db
from app.models import User, TokenBlocklist

def verify():
    app = create_app()
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['JWT_SECRET_KEY'] = 'test-secret'
    
    with app.app_context():
        db.create_all()
        
        # 1. Create a test user
        user = User(name="Test User", email="test@example.com", role="SEEKER")
        user.set_password("password123", app.extensions['bcrypt'])
        db.session.add(user)
        db.session.commit()
        
        # 2. Generate a token
        with app.test_request_context():
            token = create_access_token(identity=str(user.id))
            print(f"Generated token: {token[:20]}...")
            
            # 3. Test logout endpoint
            with app.test_client() as client:
                headers = {"Authorization": f"Bearer {token}"}
                
                # Check if token is valid initially
                res = client.get("/ping", headers=headers)
                print(f"Initial ping status: {res.status_code}")
                
                # Logout
                res = client.post("/api/auth/logout", headers=headers)
                print(f"Logout response: {res.get_json()} (Status: {res.status_code})")
                
                # Check if token is now revoked
                res = client.get("/ping", headers=headers)
                print(f"Post-logout ping status: {res.status_code}")
                
                if res.status_code == 401:
                    print("✅ VERIFICATION SUCCESS: Token revoked correctly.")
                else:
                    print(f"❌ VERIFICATION FAILED: Token still valid (Status: {res.status_code})")
                    sys.exit(1)

if __name__ == "__main__":
    verify()
