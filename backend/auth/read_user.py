from backend.database import collections
import logging
from fastapi import HTTPException
from typing import List, Optional, Dict
import bcrypt

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class UserReadManager:
    @staticmethod
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

    @staticmethod
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

    @staticmethod
    def get_current_user_profile(current_user: Dict) -> Dict:
        """
        Get the current user's profile
        
        Args:
            current_user: The user dictionary from the authentication dependency
            
        Returns:
            Dict: User profile with safe fields (no password)
        """
        try:
            # Create a copy to avoid modifying the original
            user_profile = current_user.copy()
            
            # Remove sensitive fields if they exist
            if "password" in user_profile:
                del user_profile["password"]
            if "security_answer" in user_profile:
                del user_profile["security_answer"]
            
            # Ensure the _id is a string for JSON serialization
            user_profile["_id"] = str(user_profile["_id"])
            
            return user_profile
        except Exception as e:
            logger.error(f"Error getting current user profile: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error getting user profile: {str(e)}")

    @staticmethod
    def verify_security_info(email: str, date_of_birth: str, security_question: str, security_answer: str):
        """
        Verify user security information for password recovery
        """
        try:
            # Find the user by email
            user = collections['Users'].find_one({"email": email})
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
                
            # Check date of birth
            if user.get("date_of_birth") != date_of_birth:
                raise HTTPException(status_code=400, detail="Incorrect date of birth")
                
            # Check security question
            if user.get("security_question") != security_question:
                raise HTTPException(status_code=400, detail="Incorrect security question")
                
            # Check security answer using bcrypt
            stored_answer = user.get("security_answer")
            if not stored_answer or not bcrypt.checkpw(security_answer.encode('utf-8'), stored_answer.encode('utf-8')):
                raise HTTPException(status_code=400, detail="Incorrect security answer")
                
            # Return user ID for token generation
            return {"user_id": str(user["_id"])}
        
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error verifying security info: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error verifying security information: {str(e)}")

# Export functions directly for backward compatibility
get_user_by_id = UserReadManager.get_user_by_id
get_all_users = UserReadManager.get_all_users
get_current_user_profile = UserReadManager.get_current_user_profile
verify_security_info = UserReadManager.verify_security_info 