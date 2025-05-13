from backend.database import collections
import bcrypt
import logging
from fastapi import HTTPException
from datetime import datetime, timedelta
from backend.auth.jwt_settings import create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a stored password against provided password."""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def login_user(email: str, password: str):
    """
    Authenticate a user and return access token
    """
    try:
        # Find user by email
        user = collections['Users'].find_one({"email": email})
        if user is None:
            logger.warning(f"Login attempt with non-existent email: {email}")
            raise HTTPException(status_code=401, detail="Invalid email or password")
        
        # Verify password
        if not verify_password(password, user["password"]):
            logger.warning(f"Failed login attempt for user: {email}")
            raise HTTPException(status_code=401, detail="Invalid email or password")
        
        empresa = user.get("empresa")
        if not empresa: 
            logger.warning(f"User {email} does not have an associated company")
            raise HTTPException(status_code=400, detail="User does not have an associated company")
        
        # Create and return access token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": str(user["_id"]), "empresa": empresa}, 
            expires_delta=access_token_expires
        )
        
        # Convert _id to string for JSON serialization if it's not already a string
        user_id = str(user["_id"])
        
        logger.info(f"Successful login for user: {email}")
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user_id": user_id,
            "email": user.get("email"),
            "full_name": user.get("full_name"),
            "role": user.get("role"),
            "empresa": empresa,
            "profile_picture": user.get("profile_picture")
        }
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.error(f"Unexpected error during login: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error during login") 