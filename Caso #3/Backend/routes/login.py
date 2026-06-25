from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session
from database import get_db_connection
from models import Players

router = APIRouter(
    prefix="/api",
    tags=["Authentication"]
)

class LoginRequest(BaseModel):
    username: str
    password: str  

@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db_connection)):
    sql_query = text("""
        SELECT playerId, playerStatusId 
        FROM Players 
        WHERE username = :username 
          AND passwordHash = CAST(HASHBYTES('SHA2_256', username + :password + CAST(playerId AS NVARCHAR)) AS VARBINARY(64))
          AND deletedAt IS NULL
    """)

    result = db.execute(sql_query, {
        "username": payload.username, 
        "password": payload.password
    }).fetchone()
    
    if not result:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos."
        )
    
    player_id, status_id = result
    
    if status_id != 1: 
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Esta cuenta se encuentra suspendida o inactiva."
        )
        
    return {
        "success": True, 
        "message": "Login exitoso verificado por la Base de Datos", 
        "playerId": player_id
    }