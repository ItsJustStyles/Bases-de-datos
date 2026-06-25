from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session, joinedload
from database import get_db_connection
from models import Predictions, Propositions, Players, PredictionResults, \
                   PredictionOptions, PropositionOutcomeRecords, PropositionOutcomes, \
                   Wallets, Currencies

router = APIRouter(prefix="/api", tags=["Resultados"])

@router.get("/getResultados")
async def get_resultados(
    playerId: int, 
    page: int = 1, 
    limit: int = 10, 
    db: Session = Depends(get_db_connection)
):
    try:
        offset = (page - 1) * limit

        query = db.query(Predictions).options(
            joinedload(Predictions.proposition).joinedload(Propositions.creator),
            joinedload(Predictions.proposition).joinedload(Propositions.subject_player),
            joinedload(Predictions.prediction_result),
            joinedload(Predictions.prediction_option),
            joinedload(Predictions.proposition).joinedload(Propositions.outcome_record).joinedload(PropositionOutcomeRecords.outcome),
            joinedload(Predictions.wallet).joinedload(Wallets.currency)
        ).filter(Predictions.predictorId == playerId)

        query = query.order_by(Predictions.createdAt.desc())

        resultados_raw = query.offset(offset).limit(limit).all()

        resultados = []
        for p in resultados_raw:
            opcion_code = p.prediction_option.code if p.prediction_option else None
            mi_eleccion = (
                'Apuesta a favor (SÍ)' if opcion_code == 'yes' else
                'Apuesta en contra (NO)' if opcion_code == 'no' else 'Sin definir'
            )

            resultado_code = None
            if p.proposition and p.proposition.outcome_record and p.proposition.outcome_record.outcome:
                resultado_code = p.proposition.outcome_record.outcome.code

            resultado_proposicion = (
                'Se cumplió' if resultado_code == 'yes' else
                'No se cumplió' if resultado_code == 'no' else
                'Cancelada' if resultado_code == 'cancelled' else 'Pendiente de resolución'
            )

            monto_ganado = p.prediction_result.amountEarned if p.prediction_result and p.prediction_result.amountEarned else 0
            ganancia_neta = float(monto_ganado) - float(p.amountWagered)

            resultados.append({
                "predictionId": p.predictionId,
                "DescripcionProposicion": p.proposition.propositionText if p.proposition else None,
                "CreadorProposicion": p.proposition.creator.username if (p.proposition and p.proposition.creator) else None,
                "NombreDelSujeto": p.proposition.subject_player.username if (p.proposition and p.proposition.subject_player) else None,
                "miEleccion": mi_eleccion,
                "isWinner": p.prediction_result.isWinner if p.prediction_result else None,
                "resultadoProposicion": resultado_proposicion,
                "montoInvertido": float(p.amountWagered),
                "GananciaNeta": ganancia_neta,
                "Divisa": p.wallet.currency.code if (p.wallet and p.wallet.currency) else None,
                "fechaCreacion": p.proposition.createdAt if p.proposition else None,
                "cierrePredicciones": p.proposition.predictionsCloseAt if p.proposition else None,
                "fechaAceptacion": p.proposition.acceptedAt if p.proposition else None
            })

        return {"resultados": resultados}

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail="Error interno al procesar resultados")