from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List

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

class UserLogin(BaseModel):
    """Model for user login request"""
    email: EmailStr
    password: str

class Token(BaseModel):
    """Model for JWT token response"""
    access_token: str
    token_type: str
    user_id: str
    email: str
    full_name: str
    role: str
    profile_picture: Optional[str] = None

class UserUpdate(BaseModel):
    """Model for user update request"""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None
    profile_picture: Optional[str] = None
    is_active: Optional[bool] = None

class ProfileUpdatePayload(BaseModel):
    """Model for profile update request"""
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None

class ProfilePicturePayload(BaseModel):
    """Model for profile picture upload"""
    image_base64: str

class WebProfilePicturePayload(BaseModel):
    """Model for profile picture upload from web"""
    image_base64: str
    file_name: Optional[str] = None

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

class CompanyRegistration(BaseModel):
    """Model for company registration"""
    nombre_empresa: str
    rif: str
    nombre_responsable: str
    apellido_responsable: str
    email: EmailStr
    password: str
    date_of_birth: str
    security_question: str
    security_answer: str 