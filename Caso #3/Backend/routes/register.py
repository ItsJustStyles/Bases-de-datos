import secrets
import hashlib
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional
from sqlalchemy import text
from sqlalchemy.orm import Session
from database import get_db_connection  

router = APIRouter(
    prefix="/api",
    tags=["Authentication"]
)

class RegisterRequest(BaseModel):
    username: str
    email: EmailStr  
    password: str
    countryId: Optional[int] = None  

@router.post("/register")
def register_player(payload: RegisterRequest, db: Session = Depends(get_db_connection)):
    salt_bytes = secrets.token_bytes(32)
    hash_temporal = b'\x00' * 32
    
    try:
        sp_query = text("""
            DECLARE @out_id BIGINT;
            EXEC dbo.usp_RegisterPlayer :username, :email, :hash, :salt, :countryId, @out_id OUTPUT;
            SELECT @out_id AS NewId;
        """)
        
        result = db.execute(sp_query, {
            "username": payload.username,
            "email": payload.email,
            "hash": hash_temporal, 
            "salt": salt_bytes, 
            "countryId": payload.countryId
        })
        
        new_player_id = result.scalar()

        if new_player_id is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se pudo obtener el ID del jugador registrado."
            )

        mezcla_texto = f"{payload.username}{payload.password}{new_player_id}"
        bytes_unicode = mezcla_texto.encode('utf-16-le')
        hasher = hashlib.sha256()
        hasher.update(bytes_unicode)
        hash_definitivo_bytes = hasher.digest()

        update_query = text("""
            UPDATE dbo.Players 
            SET passwordHash = :hash 
            WHERE playerId = :id
        """)
        db.execute(update_query, {"hash": hash_definitivo_bytes, "id": new_player_id})
        
        db.commit()

        return {
            "success": True,
            "playerId": new_player_id,
            "message": "Jugador registrado exitosamente."
        }

    except Exception as e:
        db.rollback() 
        print(f"Error al registrar: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Ocurrió un error en la base de datos al procesar el registro."
        )