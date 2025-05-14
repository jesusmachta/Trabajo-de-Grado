from backend.database import collections
import logging
from fastapi import HTTPException

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def delete_user(user_id: str, empresa: str):
    """
    Delete a user from the database
    """
    try:
        # Convert user_id to integer if possible
        try:
            user_id_int = int(user_id)
        except ValueError:
            user_id_int = user_id
            
        # Find the user to delete and verify company
        user = collections['Users'].find_one({"_id": user_id_int})
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
            
        # Verify user belongs to the company
        if user.get("empresa") != empresa:
            raise HTTPException(status_code=403, detail="User does not belong to your company")
            
        # Delete the user
        delete_result = collections['Users'].delete_one({"_id": user_id_int, "empresa": empresa})
        
        # Check if delete was successful
        if delete_result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="User not found or does not belong to your company")
            
        return {"success": True, "message": "User deleted successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting user: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error deleting user: {str(e)}") 