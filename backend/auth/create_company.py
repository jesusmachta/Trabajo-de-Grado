from backend.database import collections
import logging
from fastapi import HTTPException
from datetime import datetime
import re
from backend.auth.create_user import create_user, validate_name
from backend.statistics.incremental_stats import initialize_statistics
from pydantic import BaseModel, EmailStr

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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

class CompanyCreationManager:
    @staticmethod
    def create_company(nombre_empresa: str, rif: str, nombre_responsable: str, 
                      apellido_responsable: str, email: str, password: str,
                      date_of_birth: str, security_question: str, security_answer: str):
        """
        Create a new company and its administrator user
        """
        try:
            # Validate RIF (only numbers)
            if not rif.isdigit():
                raise HTTPException(
                    status_code=400,
                    detail="El RIF debe contener solo números"
                )
            
            # Validate email format
            if not re.match(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$', email):
                raise HTTPException(
                    status_code=400,
                    detail="El formato del correo electrónico es inválido"
                )
                
            # Validate nombre_responsable - must start with letters
            is_valid, error_message = validate_name(nombre_responsable)
            if not is_valid:
                raise HTTPException(
                    status_code=400,
                    detail=f"Nombre del responsable: {error_message}"
                )
                
            # Validate apellido_responsable - must start with letters
            is_valid, error_message = validate_name(apellido_responsable)
            if not is_valid:
                raise HTTPException(
                    status_code=400,
                    detail=f"Apellido del responsable: {error_message}"
                )
            
            # Check if company already exists by name
            existing_company_by_name = collections['Empresas'].find_one({"nombre": nombre_empresa})
            if existing_company_by_name:
                raise HTTPException(
                    status_code=409,
                    detail="Ya existe una empresa registrada con este nombre"
                )
            
            # Check if company already exists by RIF
            existing_company_by_rif = collections['Empresas'].find_one({"rif": rif})
            if existing_company_by_rif:
                raise HTTPException(
                    status_code=409,
                    detail="Ya existe una empresa registrada con este RIF"
                )
            
            # Check if email is already registered
            if collections['Users'].find_one({"email": email}):
                raise HTTPException(
                    status_code=409,
                    detail="Este correo electrónico ya está registrado"
                )
            
            # Create the company document
            empresa_doc = {
                "nombre": nombre_empresa,
                "rif": rif,
                "created_at": datetime.utcnow().isoformat()
            }
            
            # Insert the company into the database
            collections['Empresas'].insert_one(empresa_doc)
            
            # Create the administrator user
            full_name = f"{nombre_responsable} {apellido_responsable}"
            user_data = create_user(
                email=email,
                password=password,
                full_name=full_name,
                role="admin",  # First user of a company is always admin
                empresa=nombre_empresa,
                date_of_birth=date_of_birth,
                security_question=security_question,
                security_answer=security_answer,
                rif=int(rif) if rif.isdigit() else None
            )
            
            # Initialize statistics for the new company
            initialize_statistics(nombre_empresa)
            
            return {
                "empresa": nombre_empresa,
                "rif": rif,
                "admin_user": user_data
            }
        
        except HTTPException:
            # Re-raise HTTP exceptions
            raise
        except Exception as e:
            logger.error(f"Error creating company: {str(e)}")
            # If there was an error, attempt to clean up any partially created data
            try:
                collections['Empresas'].delete_one({"nombre": nombre_empresa})
                collections['Users'].delete_many({"empresa": nombre_empresa})
            except Exception as cleanup_error:
                logger.error(f"Error during cleanup after failed company creation: {str(cleanup_error)}")
            
            raise HTTPException(status_code=500, detail=f"Error creating company: {str(e)}")

# Export function directly for backward compatibility
create_company = CompanyCreationManager.create_company 