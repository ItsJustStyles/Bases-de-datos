from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, and_
from database import get_db_connection

from models import Players, Wallets, Currencies, Propositions, Transactions, TransactionTypes, Predictions

router = APIRouter(
    prefix="/api/inicio",
    tags=["Dashboard"]
)

@router.get("/{player_id}")
def get_dashboard_data(player_id: int, page: int = 1, limit: int = 10, db: Session = Depends(get_db_connection)):
    
    player = db.query(Players).filter(Players.playerId == player_id, Players.deletedAt == None).first()
    
    if not player:
        raise HTTPException(status_code=404, detail="Jugador no encontrado.")

    wallets_data = {
        'PTS': {'balance': 0.0, 'walletId': None}, 
        'USD': {'balance': 0.0, 'walletId': None}
    }

    balances = db.query(Currencies.code, Wallets.balance, Wallets.walletId).\
        join(Wallets, Wallets.currencyId == Currencies.currencyId).\
        filter(
            Wallets.playerId == player_id,
            Currencies.code.in_(['PTS', 'USD'])
        ).all()

    for code, balance, wallet_id in balances:
        clean_code = code.strip()
        if clean_code in wallets_data:
            wallets_data[clean_code] = {
                'balance': float(balance),
                'walletId': wallet_id
            }

    offset = (page - 1) * limit
    proposiciones_raw = db.query(Propositions).\
        options(
            joinedload(Propositions.subject_player), 
            joinedload(Propositions.creator),
            joinedload(Propositions.status)
        ).\
        order_by(Propositions.createdAt.desc()).\
        offset(offset).\
        limit(limit).\
        all()

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

    offset = (page - 1) * limit
    actividad_raw = db.query(Transactions).\
        options(
            joinedload(Transactions.wallet).joinedload(Wallets.currency), # Carga Wallet y su Currency
            joinedload(Transactions.transaction_type)                     # Carga el tipo
        ).\
        join(Wallets).\
        filter(Wallets.playerId == player_id).\
        order_by(Transactions.createdAt.desc()).\
        offset(offset).\
        limit(limit).\
        all()

    actividad = []
    for t in actividad_raw:
            c = t.wallet.currency
            tt = t.transaction_type
            
            icono = "bx-dollar" if c.code == "USD" else "bx-trophy"
            if tt.code == "withdrawal":
                icono = "bx-x-circle"
                
            actividad.append({
                "tipo": tt.code,
                "icono": icono,
                "texto": f"{t.description}: <strong>{float(t.amount)} {c.code}</strong>",
                "tiempo": t.createdAt.isoformat() if t.createdAt else ""
            })

    pred_count = db.query(func.count(Predictions.predictionId)).\
        join(Propositions, Predictions.propositionId == Propositions.propositionId).\
        filter(
            and_(
                Predictions.predictorId == player_id,
                Propositions.propositionStatusId == 6
            )
        ).scalar()

    return {
        "jugador": {
            "id": player.playerId,
            "nombre": player.username,
            "puntos": wallets_data['PTS'],
            "dineroReal": wallets_data['USD'],
            "prediccionesActivas": pred_count or 0
        },
        "proposiciones": proposiciones,
        "actividad": actividad
    }