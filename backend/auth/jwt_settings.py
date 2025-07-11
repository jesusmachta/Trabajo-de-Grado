from datetime import datetime, timedelta
import jwt

# JWT settings
SECRET_KEY = "d5ce1e8ca2d3c30ba1c6bfd87fb14943f7e75dbea2d33ca4cf54de94cb906add"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

class JWTManager:
    @staticmethod
    def create_access_token(data: dict, expires_delta: timedelta = None):
        """Create JWT token."""
        to_encode = data.copy()
        
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt

    @staticmethod
    def decode_token(token: str):
        """Decode JWT token."""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            return payload
        except jwt.PyJWTError:
            return None

# Export functions directly for backward compatibility
create_access_token = JWTManager.create_access_token
decode_token = JWTManager.decode_token 