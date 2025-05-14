from backend.database import collections
import logging
from fastapi import HTTPException
from typing import Optional, Dict, Any
from backend.auth.create_user import hash_password, validate_password
import base64
import os
from datetime import datetime
from backend.aws import upload_image_to_s3

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def update_user_profile(user_id: str, update_data: Dict[str, Any]):
    """
    Update a user's profile information
    """
    try:
        # Convert user_id to integer if possible
        try:
            user_id_int = int(user_id)
        except ValueError:
            # If not possible, keep as string
            user_id_int = user_id
            
        # Prepare update data
        clean_update_data = {}
        
        # Check for email update
        if "email" in update_data and update_data["email"] is not None:
            # Check if email is already taken by another user
            existing_user = collections['Users'].find_one({"email": update_data["email"]})
            if existing_user is not None and str(existing_user["_id"]) != str(user_id):
                raise HTTPException(status_code=400, detail="Email already registered")
            clean_update_data["email"] = update_data["email"]
        
        # Check for name update
        if "full_name" in update_data and update_data["full_name"] is not None:
            clean_update_data["full_name"] = update_data["full_name"]
        
        # Check for role update (only if admin)
        if "role" in update_data and update_data["role"] is not None:
            clean_update_data["role"] = update_data["role"]
            
        # Check for is_active update
        if "is_active" in update_data and update_data["is_active"] is not None:
            clean_update_data["is_active"] = update_data["is_active"]
        
        # Update profile picture if provided
        if "profile_picture" in update_data and update_data["profile_picture"] is not None:
            clean_update_data["profile_picture"] = update_data["profile_picture"]
        
        # Update password if provided
        if "password" in update_data and update_data["password"] is not None:
            # Validate password
            is_valid, error_message = validate_password(update_data["password"])
            if not is_valid:
                raise HTTPException(status_code=400, detail=error_message)
            clean_update_data["password"] = hash_password(update_data["password"])
        
        # Only proceed if there's something to update
        if not clean_update_data:
            return get_updated_user(user_id_int)
        
        # Update the user
        update_result = collections['Users'].update_one(
            {"_id": user_id_int},
            {"$set": clean_update_data}
        )
        
        # Check if update was successful
        if update_result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
            
        # Get and return the updated user
        return get_updated_user(user_id_int)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating user profile: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating profile: {str(e)}")

def get_updated_user(user_id):
    """Helper function to get updated user data without sensitive information"""
    updated_user = collections['Users'].find_one({"_id": user_id}, {"password": 0, "security_answer": 0})
    if updated_user:
        updated_user["_id"] = str(updated_user["_id"])
    return updated_user

def reset_password(user_id: str, new_password: str):
    """
    Reset a user's password
    """
    try:
        # Convert user_id to integer if possible
        try:
            user_id_int = int(user_id)
        except ValueError:
            user_id_int = user_id
            
        # Validate the new password
        is_valid, error_message = validate_password(new_password)
        if not is_valid:
            raise HTTPException(status_code=400, detail=error_message)
        
        # Hash the new password
        hashed_password = hash_password(new_password)
        
        # Update the password
        update_result = collections['Users'].update_one(
            {"_id": user_id_int},
            {"$set": {"password": hashed_password}}
        )
        
        # Check if update was successful
        if update_result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
            
        return {"success": True, "message": "Password updated successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error resetting password: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error resetting password: {str(e)}")

def update_profile_picture(user_id: str, profile_picture_url: str):
    """
    Update a user's profile picture
    """
    try:
        # Convert user_id to integer if possible
        try:
            user_id_int = int(user_id)
        except ValueError:
            user_id_int = user_id
            
        # Update the profile picture
        update_result = collections['Users'].update_one(
            {"_id": user_id_int},
            {"$set": {"profile_picture": profile_picture_url}}
        )
        
        # Check if update was successful
        if update_result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
            
        return {
            "profile_picture_url": profile_picture_url,
            "message": "Profile picture updated successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating profile picture: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating profile picture: {str(e)}")

def upload_profile_picture_base64(user_id: str, image_base64: str):
    """
    Upload a profile picture using base64 encoding
    """
    try:
        if not image_base64:
            raise HTTPException(status_code=400, detail="Empty image provided")
        
        # Decode the base64 image
        try:
            image_bytes = base64.b64decode(image_base64)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid base64 image: {str(e)}")
        
        # Generate a unique filename in the correct folder
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_name = f"profile_pictures/{user_id}_{timestamp}.jpeg"
        
        # Upload to S3 with public-read ACL
        s3_url = upload_image_to_s3(image_bytes, file_name, acl="public-read")
        
        # Update the user profile with the new picture URL
        update_result = update_profile_picture(user_id, s3_url)
        
        return {
            "message": "Profile picture updated successfully",
            "profile_picture_url": s3_url
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading profile picture: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error uploading profile picture: {str(e)}")

def upload_profile_picture_file(user_id: str, image_bytes: bytes, content_type: str):
    """
    Upload a profile picture from a file
    """
    try:
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty image file")
        
        # Get file extension from content type
        file_ext = content_type.split('/')[1] if content_type else 'jpg'
        if file_ext == 'jpeg' or file_ext == 'jpg':
            file_ext = 'jpg'
        elif file_ext == 'png':
            file_ext = 'png'
        else:
            file_ext = 'jpg'  # Default to jpg
        
        # Generate a unique filename in the correct folder
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_name = f"profile_pictures/{user_id}_{timestamp}.{file_ext}"
        
        # Upload to S3 with public-read ACL (will fall back if not supported)
        try:
            s3_url = upload_image_to_s3(image_bytes, file_name, acl="public-read")
        except Exception as e:
            # If setting ACL fails, try without ACL
            logger.warning(f"Error uploading with ACL, trying without: {e}")
            s3_url = upload_image_to_s3(image_bytes, file_name)
        
        # Update user record with the profile picture URL
        update_result = update_profile_picture(user_id, s3_url)
        
        return {
            "message": "Profile picture updated successfully",
            "profile_picture_url": s3_url
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading profile picture: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error uploading profile picture: {str(e)}")

def upload_profile_picture_web(user_id: str, image_base64: str, file_name: Optional[str] = None):
    """
    Upload a profile picture from web using base64
    """
    try:
        if not image_base64:
            raise HTTPException(status_code=400, detail="Empty image provided")
        
        # Decode the base64 image
        try:
            # Strip data URL prefix if present (e.g., "data:image/png;base64,")
            if "," in image_base64:
                base64_str = image_base64.split(",")[1]
            else:
                base64_str = image_base64
                
            image_bytes = base64.b64decode(base64_str)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid base64 image: {str(e)}")
        
        # Determine file extension from file_name or default to jpg
        file_ext = "jpg"
        if file_name:
            ext = os.path.splitext(file_name)[1].lower()
            if ext in ['.png', '.jpg', '.jpeg']:
                file_ext = ext.replace('.', '')
                if file_ext == 'jpeg':
                    file_ext = 'jpg'
        
        # Generate a unique filename in the correct folder
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_name = f"profile_pictures/{user_id}_{timestamp}.{file_ext}"
        
        # Upload to S3 with public-read ACL (will fall back if not supported)
        try:
            s3_url = upload_image_to_s3(image_bytes, file_name, acl="public-read")
        except Exception as e:
            # If setting ACL fails, try without ACL
            logger.warning(f"Error uploading with ACL, trying without: {e}")
            s3_url = upload_image_to_s3(image_bytes, file_name)
        
        # Update user record with the profile picture URL
        update_result = update_profile_picture(user_id, s3_url)
        
        return {
            "message": "Profile picture updated successfully",
            "profile_picture_url": s3_url
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading profile picture: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error uploading profile picture: {str(e)}") 