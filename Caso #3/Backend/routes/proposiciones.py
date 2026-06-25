from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Depends, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import text
from database import get_db_connection
from pydantic import BaseModel
# Asegúrate de importar tus modelos correctamente
from models import Propositions, Players, PropositionStatuses

router = APIRouter(
    prefix="/api",
    tags=["Proposiciones"]
)

class ProposicionCreate(BaseModel):
    creatorId: int
    subjectPlayerId: Optional[int] = None
    propositionText: str

class AceptarProposicion(BaseModel):
    propositionId: int
    subjectPlayerId: int
    predictionsCloseAt: datetime

class RechazarProposicion(BaseModel):
    propositionId: int
    subjectPlayerId: int

@router.post("/proposiciones")
async def crear_proposicion(prop: ProposicionCreate, db: Session = Depends(get_db_connection)):
    try:
        sql = text("EXEC dbo.usp_CreateProposition :creator, :subject, :text, :new_id")
        db.execute(sql, {
            "creator": prop.creatorId, 
            "subject": prop.subjectPlayerId, 
            "text": prop.propositionText,
            "new_id": 0
        })
        db.commit()
        return {"status": "success", "message": "Proposición creada exitosamente"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/getProposiciones")
async def get_proposiciones(
    db: Session = Depends(get_db_connection),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100)
):
    offset = (page - 1) * limit
    
    proposiciones_raw = db.query(Propositions)\
        .options(
            joinedload(Propositions.subject_player), 
            joinedload(Propositions.creator),
            joinedload(Propositions.status)
        )\
        .order_by(Propositions.createdAt.desc())\
        .offset(offset)\
        .limit(limit)\
        .all()

    proposiciones = []
    for pr in proposiciones_raw:
        proposiciones.append({
            "id": pr.propositionId,
            "sujeto": pr.subject_player.username if pr.subject_player else "N/A",
            "texto": pr.propositionText,
            "autor": pr.creator.username if pr.creator else "N/A",
            "cierre": pr.predictionsCloseAt.isoformat() if pr.predictionsCloseAt else "",
            "estado": pr.status.code if pr.status else "pending"
        })
    return {"proposiciones": proposiciones}

@router.get("/proposiciones/sobre-mi")
async def get_ProposicionesSobreMi(
    playerId: int, 
    db: Session = Depends(get_db_connection),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100)
):
    offset = (page - 1) * limit
    db.expire_all()
    prop_list = db.query(Propositions)\
        .options(
            joinedload(Propositions.creator),
            joinedload(Propositions.status) # Asumiendo relación 'status' en modelo
        )\
        .filter(Propositions.subjectPlayerId == playerId)\
        .order_by(Propositions.createdAt.desc())\
        .offset(offset)\
        .limit(limit)\
        .all()

    resultado = []
    for p in prop_list:
        resultado.append({
            "propositionId": p.propositionId,
            "Creador": p.creator.username if p.creator else "N/A",
            "propositionText": p.propositionText,
            "estado": p.status.code if p.status else "N/A",
            "creada": p.createdAt.isoformat() if p.createdAt else "",
            "cierre": p.predictionsCloseAt.isoformat() if p.predictionsCloseAt else ""
        })
        
    return {"proposiciones": resultado}

@router.post("/aceptProposition")
async def post_acept_proposition(prop: AceptarProposicion, db: Session = Depends(get_db_connection)):
    try:
        sql = text("EXEC dbo.usp_ActivateProposition :id, :subject, :date")
        db.execute(sql, {
            "id": prop.propositionId, 
            "subject": prop.subjectPlayerId, 
            "date": prop.predictionsCloseAt
        })
        db.commit()
        return {"status": "success", "message": "Proposición activada exitosamente."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/rejectProposition")
async def post_reject_proposition(prop: RechazarProposicion, db: Session = Depends(get_db_connection)):
    try:
        sql = text("EXEC dbo.usp_RejectProposition :id, :subject")
        db.execute(sql, {
            "id": prop.propositionId, 
            "subject": prop.subjectPlayerId
        })
        db.commit()
        return {"status": "success", "message": "Proposición rechazada exitosamente."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))