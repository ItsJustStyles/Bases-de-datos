from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Depends, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import text
from database import get_db_connection
from pydantic import BaseModel
from decimal import Decimal
from models import Predictions, Propositions, Wallets
import re


def extraer_mensaje_sql(error_sql: str) -> str:
    patron = r"\[SQL Server\](.*?)\("
    match = re.search(patron, error_sql, re.IGNORECASE)
    
    if match:
        return match.group(1).strip()
    
    return "Error al procesar la predicción."


router = APIRouter(
    prefix="/api",
    tags=["Predicciones"]
)

class CrearPrediccion(BaseModel):
    propositionId: int
    predictorId: int
    predictionOption: str
    walletId: int
    amountWagered: Decimal

@router.get("/misPredicciones")
async def getMisPredicciones(playerId: int, db: Session = Depends(get_db_connection)):
    try:

        misPredicciones = db.query(Predictions)\
            .options(
                joinedload(Predictions.proposition).joinedload(Propositions.creator),
                joinedload(Predictions.proposition).joinedload(Propositions.subject_player),
                joinedload(Predictions.wallet).joinedload(Wallets.currency),
                joinedload(Predictions.prediction_option)
            )\
            .filter(Predictions.predictorId == playerId)\
            .order_by(Predictions.createdAt.desc())\
            .all()
        resultado = []

        for p in misPredicciones:
            resultado.append({
                "predictionId": p.predictionId,
                "propositionText": p.proposition.propositionText if p.proposition else "Sin texto",
                "voto": p.prediction_option.code if p.prediction_option else "Sin voto",
                "montoApostado": p.amountWagered,
                "moneda": p.wallet.currency.code.strip() if (p.wallet and p.wallet.currency) else "N/A",
                "autor": p.proposition.creator.username if (p.proposition and p.proposition.creator) else "Anónimo",
                "sujeto": p.proposition.subject_player.username if (p.proposition and p.proposition.subject_player) else "Desconocido",
                "creada": p.createdAt,
                "cierre": p.proposition.predictionsCloseAt if p.proposition else None
            })

        return {"predicciones": resultado}

    except Exception as e:
        print(f"Error técnico: {e}") 
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al recuperar el historial de predicciones."
        )

@router.post("/predecir")
async def predecir(pred: CrearPrediccion ,db: Session = Depends(get_db_connection)):
    try:
        sp_query = text("""
            DECLARE @out_id BIGINT;
            EXEC dbo.usp_PlacePrediction :propositionId, :predictorId, :predictionOption, :walletId, :amountWagered, @out_id OUTPUT;
            SELECT @out_id AS NewId;            
        """)

        result = db.execute(sp_query, {
            "propositionId": pred.propositionId,
            "predictorId": pred.predictorId,
            "predictionOption": pred.predictionOption,
            "walletId": pred.walletId,
            "amountWagered": pred.amountWagered
        })
        new_id = result.scalar()
        db.commit()

        return {
            "message": "Predicción registrada con éxito",
            "predictionId": new_id
        }

    except Exception as e:
        db.rollback() 
        error_completo = str(e)
        mensaje_limpio = extraer_mensaje_sql(error_completo)

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=mensaje_limpio
        )