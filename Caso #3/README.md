# 🎯 Gathel — Gaming the Life

Plataforma digital de predicciones basada en eventos y acciones reales de personas, validados mediante redes sociales e inteligencia artificial. Los usuarios proponen eventos, votan proposiciones de otros jugadores y realizan predicciones sobre su resultado, ganando o perdiendo puntos y dinero real.

> Proyecto académico — Caso #3 | Bases de Datos

---

## 📋 Tabla de Contenidos

- [Descripción](#descripción)
- [Stack Tecnológico](#stack-tecnológico)
- [Arquitectura](#arquitectura)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Base de Datos](#base-de-datos)
- [Requisitos Previos](#requisitos-previos)
- [Instalación y Ejecución](#instalación-y-ejecución)
- [Endpoints de la API](#endpoints-de-la-api)
- [Seguridad y Roles](#seguridad-y-roles)
- [Niveles de Aislamiento y Problemas de Concurrencia](#niveles-de-aislamiento-y-problemas-de-concurrencia)
- [Scripts de Demo](#scripts-de-demo)

---

## Descripción

Gathel es una plataforma full-stack donde los jugadores:

- **Proponen** eventos de la vida real (con revisión por IA y votación comunitaria).
- **Predicen** el resultado de proposiciones activas (sí/no).
- **Ganan o pierden** puntos y dinero según la validación del resultado.
- **Gestionan** su billetera con depósitos, retiros y transacciones.

El proyecto cubre diseño relacional, stored procedures transaccionales, índices de rendimiento, seguridad a nivel de roles de BD, niveles de aislamiento y escenarios de deadlock.

---

## Stack Tecnológico

| Capa | Tecnología |
|------|-----------|
| Base de Datos | SQL Server 2022 |
| Migraciones | Flyway |
| Backend | FastAPI 0.111 + Python 3.12 |
| ORM | SQLAlchemy 2.0 + pyodbc |
| Frontend | HTML5 + CSS3 + JavaScript (Vanilla) |
| Servidor Web | Nginx |
| Contenedores | Docker + Docker Compose |

---

## Arquitectura

```
                        ┌─────────────────┐
                        │  gathel-frontend │  :80
                        │     (Nginx)      │
                        └────────┬────────┘
                                 │ HTTP
                        ┌────────▼────────┐
                        │  gathel-backend  │  :8000
                        │    (FastAPI)     │
                        └────────┬────────┘
                                 │ SQL / pyodbc
              ┌──────────────────▼──────────────────┐
              │           gathel-db                  │  :1434
              │        (SQL Server 2022)             │
              └──────────────────────────────────────┘
                                 ▲
                        ┌────────┴────────┐
                        │     flyway       │
                        │  (migraciones)   │
                        └─────────────────┘
```

Todos los servicios se comunican en la red interna `gathel-network` y se levantan con un solo comando de Docker Compose.

---

## Estructura del Proyecto

```
Caso-3/
├── Backend/
│   ├── main.py                  # Entrada FastAPI, routers y CORS
│   ├── database.py              # Conexión SQLAlchemy → SQL Server
│   ├── models.py                # Modelos ORM
│   ├── requirements.txt
│   ├── Dockerfile.backend
│   └── routes/
│       ├── login.py             # Autenticación (SHA2-256)
│       ├── register.py          # Registro de jugadores
│       ├── inicio.py            # Feed principal
│       ├── proposiciones.py     # CRUD de proposiciones
│       ├── predicciones.py      # Gestión de predicciones
│       ├── resultados.py        # Resultados y validación
│       ├── billetera.py         # Wallet / transacciones
│       └── otros.py             # Endpoints auxiliares
│
├── Frontend/
│   ├── html/                    # Páginas de la aplicación
│   │   ├── inicioGathel.html
│   │   ├── proposiciones.html
│   │   ├── misProposiciones.html
│   │   ├── misPredicciones.html
│   │   ├── resultados.html
│   │   ├── billetera.html
│   │   └── iniciarSesion.html
│   ├── js/                      # Lógica de cada página
│   ├── css/                     # Estilos
│   ├── nginx.conf
│   └── Dockerfile.frontend
│
├── Scripts/                     # Migraciones Flyway (orden de ejecución)
│   ├── V1__init_gathel.sql              # Esquema completo (25+ tablas)
│   ├── V2__stored_procedures_gathel.sql # SPs transaccionales
│   ├── V3__seeding_gathel.sql           # Datos iniciales
│   ├── V4__seguridad_gathel.sql         # Roles y usuarios de BD
│   ├── V5__indices_gathel.sql           # Índices base
│   ├── V6__indices_para_optimizar_ordenamiento_y_filtrado.sql
│   └── demo_scripts/
│       ├── V7__setup_datos_demo.sql
│       ├── V8__transacciones_anidadas.sql
│       ├── V9__deadlock_escritura_escritura.sql
│       ├── V10__deadlock_select_escritura.sql
│       └── V11__deadlock_ciclico.sql
│
├── Markdowns/
│   ├── Gathel_db_design.md      # Diseño completo de la base de datos
│   └── stored_procedured.md     # Documentación de SPs
│
├── scripts_demo_pruebas/        # Scripts SQL para ejecutar demos manualmente
├── Problemas_nivel_de_aislamiento.md
├── Documentacion_Flyway.md
├── Documentacion_Agente_IA_Gathel.pdf
└── docker-compose.yml
```

---

## Base de Datos

La base de datos **GathelDB** corre sobre SQL Server 2022 y contiene más de 25 tablas organizadas en los siguientes dominios:

| Dominio | Tablas principales |
|---------|-------------------|
| Jugadores | `Players`, `PlayerStatuses`, `PlayerDevices`, `SocialAccounts` |
| Wallets | `Wallets`, `Currencies`, `Transactions`, `TransactionTypes`, `TransactionDetails` |
| Proposiciones | `Propositions`, `PropositionStatuses`, `PropositionVotes` |
| Predicciones | `Predictions`, `PredictionOptions`, `PredictionResults` |
| IA | `AIProviders`, `AIModels`, `AIAnalysisJobs`, `AIAnalysisResults` |
| Seguridad | `AuditLog`, `PenaltyCatalog`, `PenaltyTransactions` |
| Plataforma | `PlatformConfig`, `Countries`, `Affiliates` |

### Stored Procedures principales

| SP | Descripción |
|----|-------------|
| `usp_RegisterPlayer` | Registra jugador, crea wallets (PTS + USD) y otorga puntos de bienvenida |
| `usp_PlacePrediction` | Registra una predicción y descuenta el wager del wallet |
| `usp_ProcessPredictionResults` | Valida resultados y distribuye ganancias/pérdidas |
| `usp_DepositFunds` | Procesa depósitos a billetera |

---

## Requisitos Previos

- [Docker](https://www.docker.com/) y Docker Compose instalados.
- Puerto `80`, `8000` y `1434` disponibles en la máquina.

---

## Instalación y Ejecución

### 1. Clonar el repositorio

```bash
git clone https://github.com/ItsJustStyles/Caso-3.git
cd Caso-3
```

### 2. Levantar todos los servicios

```bash
DESARROLLADOR_NAME="tu_nombre" docker compose up -d
```

Docker Compose levanta los servicios en el orden correcto:
1. **gathel-db** — SQL Server 2022 (espera hasta estar healthy).
2. **flyway** — Aplica todas las migraciones automáticamente.
3. **gathel-backend** — FastAPI en `http://localhost:8000`.
4. **gathel-frontend** — Nginx sirviendo el frontend en `http://localhost`.

### 3. Acceder a la aplicación

| Servicio | URL |
|----------|-----|
| Frontend | http://localhost |
| API Docs (Swagger) | http://localhost:8000/docs |
| API ReDoc | http://localhost:8000/redoc |

### 4. Detener los servicios

```bash
docker compose down o docker compose stop
```

---

## Endpoints de la API

Base URL: `http://localhost:8000/api`

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/login` | Autenticación de jugador |
| `POST` | `/register` | Registro de nuevo jugador |
| `GET` | `/inicio` | Feed de proposiciones activas |
| `GET/POST` | `/proposiciones` | Listado y creación de proposiciones |
| `GET` | `/mis-proposiciones` | Proposiciones del jugador autenticado |
| `GET/POST` | `/predicciones` | Predicciones del jugador |
| `GET` | `/resultados` | Resultados y validaciones |
| `GET` | `/billetera` | Estado del wallet y transacciones |

---

## Seguridad y Roles

`V4__seguridad_gathel.sql` define 4 roles de base de datos con permisos de mínimo privilegio:

| Rol | Permisos |
|-----|----------|
| `rol_soporte_lectura` | Lectura de `Players` (sin columnas de password) y `Wallets` |
| `rol_moderacion` | Actualización de estado de jugadores (`playerStatusId`) |
| `rol_finanzas` | Control total sobre `Wallets` y `Transactions` |
| `rol_auditoria` | Sin acceso directo a tablas — solo vía Stored Procedures |

Las contraseñas se almacenan como `VARBINARY(64)` usando `HASHBYTES('SHA2_256', username + password + playerId)`.

---

## Niveles de Aislamiento y Problemas de Concurrencia

El proyecto documenta y demuestra los cuatro problemas clásicos de concurrencia sobre las tablas de Gathel:

| Nivel | Problema demostrado |
|-------|-------------------|
| `READ UNCOMMITTED` | **Dirty Read** — lectura de un cambio que después se revierte |
| `READ COMMITTED` | **Non-repeatable Read** — dos lecturas del mismo dato en la misma transacción devuelven valores distintos |
| `REPEATABLE READ` | **Phantom Read** — el conteo de filas cambia entre dos SELECTs de la misma transacción |
| `SERIALIZABLE` | Nivel sin anomalías, con sus implicaciones de rendimiento |

Ver [`Problemas_nivel_de_aislamiento.md`](./Problemas_nivel_de_aislamiento.md) para scripts y explicaciones detalladas.

---

## Scripts de Demo

Los scripts en `scripts_demo_pruebas/` permiten reproducir manualmente escenarios de concurrencia:

| Script | Escenario |
|--------|-----------|
| `deadlock_escritura_escritura.sql` | Deadlock entre dos transacciones que actualizan filas en orden inverso |
| `deadlock_select_escritura.sql` | Deadlock entre un SELECT con lock y una escritura |
| `deadlock_ciclico.sql` | Deadlock cíclico de tres transacciones |
| `flujo_de_3_sps.sql` | Ejecución encadenada de stored procedures transaccionales |