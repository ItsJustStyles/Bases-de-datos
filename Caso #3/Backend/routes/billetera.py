from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session, joinedload
from database import get_db_connection
from models import PaymentMethods, Transactions, Wallets, Currencies, TransactionTypes

router = APIRouter(
    prefix="/api",
    tags=["Billetera"]
)

@router.get("/billetera")
async def get_billetera(playerId: int, db: Session = Depends(get_db_connection)):
    try:
        metodos_raw = db.query(PaymentMethods)\
            .filter(PaymentMethods.playerId == playerId)\
            .all()

        metodos = [
            {
                "id": m.paymentMethodId, 
                "tipo": m.methodType, 
                "alias": m.alias, 
                "verificado": m.isVerified
            } 
            for m in metodos_raw
        ]

        movimientos_raw = db.query(Transactions)\
            .join(Wallets, Transactions.walletId == Wallets.walletId)\
            .options(
                joinedload(Transactions.wallet).joinedload(Wallets.currency),
                joinedload(Transactions.transaction_type)
            )\
            .filter(Wallets.playerId == playerId)\
            .order_by(Transactions.createdAt.desc())\
            .all()

        movimientos = [
            {
                "transactionId": t.transactionId,
                "fecha": t.createdAt.isoformat() if t.createdAt else None,
                "monto": float(t.amount),
                "moneda": t.wallet.currency.code if (t.wallet and t.wallet.currency) else "N/A",
                "tipo": t.transaction_type.code if t.transaction_type else "N/A",
                "descripcion": t.description
            }
            for t in movimientos_raw
        ]

        return {
            "metodosPago": metodos,
            "movimientos": movimientos
        }

    except Exception as e:
        print(f"Error en /billetera: {str(e)}") 
        raise HTTPException(status_code=500, detail="Error interno al consultar la billetera")