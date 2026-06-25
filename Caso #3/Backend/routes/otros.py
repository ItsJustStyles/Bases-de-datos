from fastapi import APIRouter, HTTPException, Query, Depends
from sqlalchemy.orm import Session, joinedload
from database import get_db_connection
from models import Players

router = APIRouter(
    prefix="/api",
    tags=["Otros"]
)

@router.get("/buscarUsuarios")
async def buscarUsuarios(query: str = Query(...), db: Session = Depends(get_db_connection)):
    resultados = db.query(Players)\
        .filter(Players.username.ilike(f"{query}%"))\
        .order_by(Players.username.asc())\
        .limit(5)\
        .all()
    
    return [{"id": p.playerId, "username": p.username} for p in resultados]