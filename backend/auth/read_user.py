from backend.database import collections
import logging
from fastapi import HTTPException
from typing import List, Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_user_by_id(user_id: str):
    """
    Get user by ID
    """
    try:
        # Try to find user with both string and integer ID formats
        try:
            user_id_int = int(user_id)
            user = collections['Users'].find_one({"_id": user_id_int})
        except ValueError:
            user = None
            
        # If not found with integer ID, try with string ID
        if user is None:
            user = collections['Users'].find_one({"_id": user_id})
            
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
            
        # Remove sensitive fields
        if "password" in user:
            del user["password"]
        if "security_answer" in user:
            del user["security_answer"]
            
        # Convert ObjectId to string for JSON serialization
        user["_id"] = str(user["_id"])
        
        return user
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user by ID: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error getting user: {str(e)}")

def get_all_users(empresa: str) -> List[dict]:
    """
    Get all users for a specific company
    """
    try:
        # Get all users from the same company, excluding sensitive fields
        users = list(collections['Users'].find(
            {"empresa": empresa},
            {"password": 0, "security_answer": 0}
        ))

        # Convert ObjectId to string for serialization
        for user in users:
            user["_id"] = str(user["_id"])

        return users
    except Exception as e:
        logger.error(f"Error fetching users for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching users: {str(e)}")

def verify_security_info(email: str, date_of_birth: str, security_question: str, security_answer: str):
    """
    Verify user security information for password recovery
    """
    try:
        from backend.auth.login_user import verify_password
        
        # Find user by email
        user = collections['Users'].find_one({"email": email})
        if not user:
            raise HTTPException(
                status_code=404,
                detail="Usuario no encontrado con este correo electrónico"
            )
        
        # Verify date of birth
        if user.get("date_of_birth") != date_of_birth:
            raise HTTPException(
                status_code=400,
                detail="La fecha de nacimiento no coincide"
            )
        
        # Verify security question
        if user.get("security_question") != security_question:
            raise HTTPException(
                status_code=400,
                detail="La pregunta de seguridad no coincide"
            )
        
        # Verify security answer
        if not verify_password(security_answer, user.get("security_answer", "")):
            raise HTTPException(
                status_code=400,
                detail="La respuesta de seguridad no es correcta"
            )
        
        # All checks passed
        return {"user_id": str(user["_id"])}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error verifying security info: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error verifying security information: {str(e)}") 