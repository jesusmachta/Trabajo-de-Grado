from fastapi import Depends, HTTPException
# from backend.routes import get_current_user  # Importar get_current_user desde routes.py
from fastapi.security import OAuth2PasswordBearer
from backend.database import collections
from jose import jwt


SECRET_KEY = "d5ce1e8ca2d3c30ba1c6bfd87fb14943f7e75dbea2d33ca4cf54de94cb906add"
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Decode JWT token to get current user."""
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        empresa: str = payload.get("empresa")
        print("get_current_user. Empresa: "+ empresa)
        if user_id is None or empresa is None:
            raise credentials_exception
    except jwt.JWTError:
        raise credentials_exception
    
    try:
        # Try to find user with both string and integer ID formats
        user = collections['Users'].find_one({"_id": int(user_id)})
        if user is None:
            # Try with string version as fallback
            user = collections['Users'].find_one({"_id": user_id})
            if user is None:
                raise credentials_exception
    except (ValueError, TypeError):
        # If int conversion fails, try with string directly
        user = collections['Users'].find_one({"_id": user_id})
        if user is None:
            raise credentials_exception
        if user.get("empresa") != empresa:
           raise HTTPException(status_code=403, detail="User does not belong to the specified company")  
    
    return user

def get_empresa(current_user: dict = Depends(get_current_user)):
    """Extrae la empresa del usuario autenticado."""
    empresa = current_user.get("empresa")
    print("get_empresa. Empresa: "+ empresa)
    if not empresa:
        raise HTTPException(status_code=403, detail="User does not belong to any company")
    return empresa

# def get_empresa():
#     """Extrae la empresa del usuario autenticado."""
#     current_user = get_current_user()

#     empresa = current_user.get("empresa")
#     print("get_empresa. Empresa: "+ empresa)
#     if not empresa:
#         raise HTTPException(status_code=403, detail="User does not belong to any company")
#     return empresa