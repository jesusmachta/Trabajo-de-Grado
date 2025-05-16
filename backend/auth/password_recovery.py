from datetime import datetime, timedelta
import logging
import jwt
from fastapi import APIRouter, Body, HTTPException
from backend.auth.read_user import verify_security_info
from backend.auth.update_user import reset_password
from backend.auth.jwt_settings import create_access_token, SECRET_KEY, ALGORITHM

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/forgot-password/verify", status_code=200)
async def verify_security_info_endpoint(
    data: dict = Body(...)
):
    """
    Endpoint to verify email, date of birth, and security question/answer for password recovery.
    """
    required_fields = ["email", "date_of_birth", "security_question", "security_answer"]
    for field in required_fields:
        if field not in data:
            raise HTTPException(
                status_code=400,
                detail=f"El campo '{field}' es requerido"
            )
    
    # Use the verify_security_info function from the model
    verification_result = verify_security_info(
        email=data["email"],
        date_of_birth=data["date_of_birth"],
        security_question=data["security_question"],
        security_answer=data["security_answer"]
    )
    
    # Generate token for password reset
    reset_token = create_access_token(
        data={"sub": verification_result["user_id"], "purpose": "password_reset"},
        expires_delta=timedelta(minutes=15)
    )
    
    return {
        "message": "Verificación exitosa",
        "reset_token": reset_token,
        "user_id": verification_result["user_id"]
    }

@router.post("/reset-password", status_code=200)
async def reset_password_endpoint(
    data: dict = Body(...)
):
    """
    Endpoint to change password after security verification.
    """
    if "reset_token" not in data or "new_password" not in data:
        raise HTTPException(
            status_code=400,
            detail="Se requieren 'reset_token' y 'new_password'"
        )
    
    reset_token = data["reset_token"]
    new_password = data["new_password"]
    
    try:
        # Verify the token
        payload = jwt.decode(reset_token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        purpose = payload.get("purpose")
        
        if not user_id or purpose != "password_reset":
            raise HTTPException(
                status_code=401,
                detail="Token de restablecimiento inválido"
            )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=401,
            detail="Token de restablecimiento inválido o expirado"
        )
    
    # Use the reset_password function from the model
    result = reset_password(user_id, new_password)
    
    return {
        "message": "Contraseña actualizada exitosamente"
    } 