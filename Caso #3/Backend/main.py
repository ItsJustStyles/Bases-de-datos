import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes import login, register, inicio, proposiciones, resultados, billetera, predicciones, otros

app = FastAPI(
    title="Gathel API",
    description="Backend modularizado para la plataforma de predicciones Gathel",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(login.router)
app.include_router(register.router)
app.include_router(inicio.router)
app.include_router(proposiciones.router)
app.include_router(resultados.router)
app.include_router(billetera.router)
app.include_router(predicciones.router)
app.include_router(otros.router)

@app.get("/")
def read_root():
    return {"message": "El backend de Gathel está corriendo perfectamente."}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)