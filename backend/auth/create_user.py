from backend.database import collections
import bcrypt
import re
import logging
from fastapi import HTTPException
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class UserCreate(BaseModel):
    """Model for user creation request"""
    email: EmailStr
    password: str
    full_name: str
    role: str = "user"  # default role
    date_of_birth: str  # Add date of birth field
    security_question: str  # Add security question field
    security_answer: str  # Add security answer field
    rif: Optional[int] = None

class UserCreationManager:
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash a password for storing."""
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        return hashed.decode('utf-8')

    @staticmethod
    def validate_password(password: str) -> tuple[bool, str]:
        """
        Validates a password against the following criteria:
        - Minimum 6 characters
        - Minimum 1 uppercase letter
        - Minimum 1 lowercase letter
        - Minimum 1 special character
        - Minimum 1 number
        
        Returns:
        - (True, "") if password is valid
        - (False, error_message) if not valid
        """
        # Check minimum length
        if len(password) < 6:
            return False, "La contraseña debe tener al menos 6 caracteres"
        
        # Check if contains at least one uppercase letter
        if not re.search(r'[A-Z]', password):
            return False, "La contraseña debe contener al menos una letra mayúscula"
        
        # Check if contains at least one lowercase letter
        if not re.search(r'[a-z]', password):
            return False, "La contraseña debe contener al menos una letra minúscula"
        
        # Check if contains at least one special character
        if not re.search(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?]', password):
            return False, "La contraseña debe contener al menos un carácter especial"
        
        # Check if contains at least one number
        if not re.search(r'[0-9]', password):
            return False, "La contraseña debe contener al menos un número"
        
        return True, ""

    @staticmethod
    def validate_name(name: str) -> tuple[bool, str]:
        """
        Validates that a name starts with a word (letters), not with numbers or special characters.
        
        Returns:
        - (True, "") if name is valid
        - (False, error_message) if not valid
        """
        # Check if the name starts with at least one letter
        if not re.match(r'^[a-zA-Z]', name):
            return False, "El nombre debe comenzar con letras, no con números o caracteres especiales"
        
        return True, ""

    @staticmethod
    def get_next_sequence_value(sequence_name):
        """Get next sequence value from the counters collection."""
        try:
            import pymongo
            sequence_document = collections['counters'].find_one_and_update(
                {"_id": sequence_name},
                {"$inc": {"seq": 1}},
                return_document=pymongo.ReturnDocument.AFTER
            )
            if sequence_document is None:
                raise Exception("Sequence document not found")
            return sequence_document["seq"]
        except Exception as e:
            logger.error(f"Error al obtener el siguiente valor de secuencia: {e}")
            raise HTTPException(status_code=500, detail=f"Error al obtener el siguiente valor de secuencia: {e}")

    @staticmethod
    def create_user(email: str, password: str, full_name: str, role: str, 
                    empresa: str, date_of_birth: str, security_question: str, 
                    security_answer: str, rif: Optional[int] = None):
        """
        Create a new user in the database
        """
        try:
            # Check if user already exists
            if collections['Users'].find_one({"email": email}) is not None:
                raise HTTPException(status_code=400, detail="Email already registered")
            
            # Validate password
            is_valid, error_message = UserCreationManager.validate_password(password)
            if not is_valid:
                raise HTTPException(status_code=400, detail=error_message)
            
            # Validate full name - ensure first and last names start with letters
            name_parts = full_name.split()
            if len(name_parts) > 0:
                # Validate first name
                is_valid, error_message = UserCreationManager.validate_name(name_parts[0])
                if not is_valid:
                    raise HTTPException(status_code=400, detail=f"Nombre: {error_message}")
                
                # If there's a last name, validate it too
                if len(name_parts) > 1:
                    is_valid, error_message = UserCreationManager.validate_name(name_parts[1])
                    if not is_valid:
                        raise HTTPException(status_code=400, detail=f"Apellido: {error_message}")
            
            # Create new user
            user_id = UserCreationManager.get_next_sequence_value("user_id")
            hashed_password = UserCreationManager.hash_password(password)
            # Hash security answer
            hashed_security_answer = UserCreationManager.hash_password(security_answer)
            
            # Create user document
            user = {
                "_id": user_id,
                "email": email,
                "password": hashed_password,
                "full_name": full_name,
                "role": role,
                "empresa": empresa,
                "created_at": datetime.utcnow().isoformat(),
                "date_of_birth": date_of_birth,
                "security_question": security_question,
                "security_answer": hashed_security_answer,
                "is_active": True
            }
            
            if rif is not None:
                user["rif"] = rif
            
            # Insert user into database
            collections['Users'].insert_one(user)
            
            # Return the user id (without sensitive info)
            return {
                "user_id": str(user_id),
                "email": email,
                "full_name": full_name,
                "role": role,
                "empresa": empresa
            }
        
        except HTTPException as he:
            # Re-raise HTTP exceptions
            raise he
        except Exception as e:
            logger.error(f"Error creating user: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error creating user: {str(e)}")

# Export functions directly for backward compatibility
hash_password = UserCreationManager.hash_password
validate_password = UserCreationManager.validate_password
validate_name = UserCreationManager.validate_name
get_next_sequence_value = UserCreationManager.get_next_sequence_value
create_user = UserCreationManager.create_user 