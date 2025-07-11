from fastapi import Depends, HTTPException
# from backend.routes import get_current_user  # Importar get_current_user desde routes.py
from fastapi.security import OAuth2PasswordBearer
from backend.database import collections
from backend.auth.jwt_settings import decode_token


SECRET_KEY = "d5ce1e8ca2d3c30ba1c6bfd87fb14943f7e75dbea2d33ca4cf54de94cb906add"
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/login")

class DependencyManager:
    @staticmethod
    async def get_current_user(token: str = Depends(oauth2_scheme)):
        """Decode JWT token to get current user."""
        credentials_exception = HTTPException(
            status_code=401,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
        # Decode the token
        payload = decode_token(token)
        if payload is None:
            raise credentials_exception
            
        user_id = payload.get("sub")
        company = payload.get("empresa")
        if user_id is None or company is None:
            raise credentials_exception
        
        try:
            # Try to find user with both string and integer ID formats
            try:
                user = collections['Users'].find_one({"_id": int(user_id)})
            except ValueError:
                user = None
                
            if user is None:
                # Try with string version as fallback
                user = collections['Users'].find_one({"_id": user_id})
                if user is None:
                    raise credentials_exception
                    
            if user.get("empresa") != company:
               raise HTTPException(status_code=403, detail="User does not belong to the specified company")  
        
        except (ValueError, TypeError):
            # If int conversion fails, try with string directly
            user = collections['Users'].find_one({"_id": user_id})
            if user is None:
                raise credentials_exception
            if user.get("empresa") != company:
               raise HTTPException(status_code=403, detail="User does not belong to the specified company")  
        
        return user

    @staticmethod
    async def get_empresa(token: str = Depends(oauth2_scheme)):
        """Extract the empresa (company) from the JWT token."""
        payload = decode_token(token)
        if payload is None:
            raise HTTPException(
                status_code=401,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        empresa = payload.get("empresa")
        if empresa is None:
            raise HTTPException(
                status_code=401,
                detail="Company information not found in token",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        return empresa

# Export functions directly for backward compatibility
get_current_user = DependencyManager.get_current_user
get_empresa = DependencyManager.get_empresa

# def get_empresa():
#     """Extrae la empresa del usuario autenticado."""
#     current_user = get_current_user()

#     empresa = current_user.get("empresa")
#     print("get_empresa. Empresa: "+ empresa)
#     if not empresa:
#         raise HTTPException(status_code=403, detail="User does not belong to any company")
#     return empresa