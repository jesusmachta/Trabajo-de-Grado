from backend.database import collections
import logging
from fastapi import HTTPException
from typing import Optional, Dict, Any
from backend.auth.create_user import hash_password, validate_password, validate_name
from backend.auth.login_user import verify_password
import base64
import os
from datetime import datetime
from backend.aws import upload_image_to_s3
from pydantic import BaseModel, EmailStr
import bcrypt

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class UserUpdate(BaseModel):
    """Model for user update request"""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None
    profile_picture: Optional[str] = None
    is_active: Optional[bool] = None
    security_question: Optional[str] = None
    security_answer: Optional[str] = None

class ProfileUpdatePayload(BaseModel):
    """Model for profile update request"""
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    current_password: Optional[str] = None
    current_security_question: Optional[str] = None
    current_security_answer: Optional[str] = None
    new_security_question: Optional[str] = None
    new_security_answer: Optional[str] = None

class ProfilePicturePayload(BaseModel):
    """Model for profile picture upload"""
    image_base64: str

class WebProfilePicturePayload(BaseModel):
    """Model for profile picture upload from web"""
    image_base64: str
    file_name: Optional[str] = None
    user_id: Optional[str] = None

class PasswordResetRequest(BaseModel):
    """Model for password reset verification"""
    email: EmailStr
    date_of_birth: str
    security_question: str
    security_answer: str

class PasswordResetConfirm(BaseModel):
    """Model for password reset confirmation"""
    reset_token: str
    new_password: str

class UserUpdateManager:
    @staticmethod
    def update_user_profile(user_id: str, update_data: Dict[str, Any]):
        """
        Update a user's profile information
        """
        try:
            # Add detailed logging to help with debugging
            logger.info(f"Update requested for user {user_id}")
            logger.info(f"Update data keys: {list(update_data.keys())}")
            
            # Convert user_id to integer if possible
            try:
                user_id_int = int(user_id)
            except ValueError:
                # If not possible, keep as string
                user_id_int = user_id
                
            # Get current user data
            current_user = collections['Users'].find_one({"_id": user_id_int})
            if not current_user:
                raise HTTPException(status_code=404, detail="User not found")
                
            # Prepare update data
            clean_update_data = {}
            
            # Check for email update
            if "email" in update_data and update_data["email"] is not None:
                # Check if email is already taken by another user
                existing_user = collections['Users'].find_one({"email": update_data["email"]})
                if existing_user is not None and str(existing_user["_id"]) != str(user_id):
                    raise HTTPException(status_code=400, detail="Email already registered")
                clean_update_data["email"] = update_data["email"]
            
            # Check for name update - either full_name or first_name/last_name
            if "full_name" in update_data and update_data["full_name"] is not None:
                # Validate that names start with letters
                name_parts = update_data["full_name"].split()
                if len(name_parts) > 0:
                    # Validate first name
                    is_valid, error_message = validate_name(name_parts[0])
                    if not is_valid:
                        raise HTTPException(status_code=400, detail=f"Nombre: {error_message}")
                    
                    # If there's a last name, validate it too
                    if len(name_parts) > 1:
                        is_valid, error_message = validate_name(name_parts[1])
                        if not is_valid:
                            raise HTTPException(status_code=400, detail=f"Apellido: {error_message}")
                
                clean_update_data["full_name"] = update_data["full_name"]
            elif "first_name" in update_data or "last_name" in update_data:
                # Handle separate first/last name fields
                current_full_name = current_user.get("full_name", "")
                name_parts = current_full_name.split(" ", 1)
                
                current_first = name_parts[0] if len(name_parts) > 0 else ""
                current_last = name_parts[1] if len(name_parts) > 1 else ""
                
                new_first = update_data.get("first_name") if update_data.get("first_name") is not None else current_first
                new_last = update_data.get("last_name") if update_data.get("last_name") is not None else current_last
                
                # Validate first name if it's being updated
                if update_data.get("first_name") is not None:
                    is_valid, error_message = validate_name(new_first)
                    if not is_valid:
                        raise HTTPException(status_code=400, detail=f"Nombre: {error_message}")
                
                # Validate last name if it's being updated
                if update_data.get("last_name") is not None:
                    is_valid, error_message = validate_name(new_last)
                    if not is_valid:
                        raise HTTPException(status_code=400, detail=f"Apellido: {error_message}")
                
                clean_update_data["full_name"] = f"{new_first} {new_last}".strip()
            
            # Check for role update (only if admin)
            if "role" in update_data and update_data["role"] is not None:
                clean_update_data["role"] = update_data["role"]
                
            # Check for is_active update
            if "is_active" in update_data and update_data["is_active"] is not None:
                clean_update_data["is_active"] = update_data["is_active"]
            
            # Check for profile picture update
            if "profile_picture" in update_data:
                # If empty string is provided, it means remove the profile picture
                if update_data["profile_picture"] == "":
                    clean_update_data["profile_picture"] = None
                    logger.info(f"Removing profile picture for user {user_id}")
                else:
                    clean_update_data["profile_picture"] = update_data["profile_picture"]
                    logger.info(f"Updating profile picture for user {user_id}")
            
            # Update password if provided
            if "password" in update_data and update_data["password"] is not None:
                # Validate password
                is_valid, error_message = validate_password(update_data["password"])
                if not is_valid:
                    raise HTTPException(status_code=400, detail=error_message)
                
                # Verify current password if provided
                if "current_password" in update_data and update_data["current_password"] is not None:
                    # Check if current password is correct
                    if not verify_password(update_data["current_password"], current_user["password"]):
                        raise HTTPException(status_code=400, detail="La contraseña actual es incorrecta")
                else:
                    # If we're changing password, current password must be provided
                    raise HTTPException(status_code=400, detail="Se requiere la contraseña actual para cambiar la contraseña")
                
                clean_update_data["password"] = hash_password(update_data["password"])
            
            # Update security question/answer if provided
            if (("new_security_question" in update_data and update_data["new_security_question"] is not None) and
                ("new_security_answer" in update_data and update_data["new_security_answer"] is not None)):
                
                # Both fields must be provided
                if not update_data.get("new_security_question") or not update_data.get("new_security_answer"):
                    raise HTTPException(status_code=400, detail="Se requiere tanto la nueva pregunta como la nueva respuesta de seguridad")
                
                # Check if this is an admin updating security details
                is_admin_update = update_data.get("admin_security_update", False)
                
                if not is_admin_update:
                    # Regular user update flow - verify current question and answer
                    # Verify current security question and answer
                    if not update_data.get("current_security_question") or not update_data.get("current_security_answer"):
                        logger.warning("Missing current security question or answer")
                        raise HTTPException(status_code=400, detail="Se requiere la pregunta y respuesta de seguridad actuales")
                    
                    # Verify current security question matches
                    if update_data["current_security_question"] != current_user.get("security_question"):
                        logger.warning(f"Current security question mismatch. Provided: {update_data['current_security_question']}, Actual: {current_user.get('security_question')}")
                        raise HTTPException(status_code=400, detail="La pregunta de seguridad actual es incorrecta")
                    
                    # Verify current security answer using bcrypt
                    try:
                        is_valid = bcrypt.checkpw(
                            update_data["current_security_answer"].encode('utf-8'), 
                            current_user["security_answer"].encode('utf-8')
                        )
                        if not is_valid:
                            logger.warning("Invalid security answer provided")
                            raise HTTPException(status_code=400, detail="La respuesta de seguridad actual es incorrecta")
                    except Exception as e:
                        logger.error(f"Error verifying security answer: {str(e)}")
                        raise HTTPException(status_code=400, detail="Error al verificar la respuesta de seguridad")
                else:
                    # Admin update flow - just need current question for reference, no verification needed
                    logger.info(f"Admin is updating security question/answer for user {user_id}")
                
                # Update security question and answer
                logger.info(f"Updating security question to: {update_data['new_security_question']}")
                clean_update_data["security_question"] = update_data["new_security_question"]
                clean_update_data["security_answer"] = hash_password(update_data["new_security_answer"])
            
            # Only proceed if there's something to update
            if not clean_update_data:
                logger.info(f"No changes to update for user {user_id}")
                return UserUpdateManager.get_updated_user(user_id_int)
            
            # Log the fields being updated
            logger.info(f"Updating fields for user {user_id}: {list(clean_update_data.keys())}")
            
            # Update the user
            update_result = collections['Users'].update_one(
                {"_id": user_id_int},
                {"$set": clean_update_data}
            )
            
            # Check if update was successful
            if update_result.matched_count == 0:
                logger.warning(f"No user found with ID {user_id} during update")
                raise HTTPException(status_code=404, detail="User not found")
            
            logger.info(f"User {user_id} successfully updated")
                
            # Get and return the updated user
            return UserUpdateManager.get_updated_user(user_id_int)
        
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error updating user profile: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error updating profile: {str(e)}")

    @staticmethod
    def get_updated_user(user_id):
        """Helper function to get updated user data without sensitive information"""
        updated_user = collections['Users'].find_one({"_id": user_id}, {"password": 0, "security_answer": 0})
        if updated_user:
            updated_user["_id"] = str(updated_user["_id"])
        return updated_user

    @staticmethod
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

    @staticmethod
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

    @staticmethod
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
            update_result = UserUpdateManager.update_profile_picture(user_id, s3_url)
            
            return {
                "message": "Profile picture updated successfully",
                "profile_picture_url": s3_url
            }
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error uploading profile picture: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error uploading profile picture: {str(e)}")

    @staticmethod
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
            update_result = UserUpdateManager.update_profile_picture(user_id, s3_url)
            
            return {
                "message": "Profile picture updated successfully",
                "profile_picture_url": s3_url
            }
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error uploading profile picture: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error uploading profile picture: {str(e)}")

    @staticmethod
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
            update_result = UserUpdateManager.update_profile_picture(user_id, s3_url)
            
            return {
                "message": "Profile picture updated successfully",
                "profile_picture_url": s3_url
            }
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error uploading profile picture: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error uploading profile picture: {str(e)}")

# Export functions directly for backward compatibility
update_user_profile = UserUpdateManager.update_user_profile
reset_password = UserUpdateManager.reset_password
update_profile_picture = UserUpdateManager.update_profile_picture
upload_profile_picture_base64 = UserUpdateManager.upload_profile_picture_base64
upload_profile_picture_file = UserUpdateManager.upload_profile_picture_file
upload_profile_picture_web = UserUpdateManager.upload_profile_picture_web
get_updated_user = UserUpdateManager.get_updated_user 