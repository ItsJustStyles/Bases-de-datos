- Database engine: SQL Server 2022
- Database name: GathelDB
- Context: Plataforma digital de predicciones basada en eventos y acciones reales de personas, validados mediante redes sociales e inteligencia artificial.

---

# Correcciones aplicadas

1. **PointsConfig → PlatformConfig con vigencia temporal** — los valores de configuración ahora tienen `effectiveFrom`/`effectiveTo` para soportar cambios en el tiempo.
2. **Todos los `status`, `type`, `outcome`, `action` normalizados a catálogos** — eliminados todos los `nvarchar` de estados hardcodeados.
3. **Withdrawals eliminado como tabla separada** — es un tipo de transacción; ahora se registra como `TransactionType = 'withdrawal'` en Transactions, con detalle en `TransactionDetails`.
4. **Password en Players corregido** — ahora `varbinary(64)` para hash real; salt en columna separada.
5. **SessionToken** — ahora `char(64)` (hash SHA-256 en hex), no varchar(500).
6. **UserAgent** — movido a tabla `PlayerDevices`; separado en campos estructurados.
7. **Wallets unificado** — puntos y dinero son la misma entidad `Wallet` con `currencyId`; los puntos son una `Currency` más (código `PTS`).
8. **AuditLog corregido** — aplica patrón de logs: `entityName`, `entityId`, `operation`, `performedBy`, `sessionId`, `ipAddress`, `oldSnapshot` (JSON), `newSnapshot` (JSON), `correlationId`.
9. **AIAnalysisJobs corregido** — separados en `AIProviders`, `AIModels`, `AIAnalysisJobs` (request) y `AIAnalysisResults` (response); se sabe qué provider, qué modelo, qué versión usó cada análisis.
10. **Penalties corregido** — separado en `PenaltyCatalog` (configuración con vigencia), y `PenaltyTransactions` (registro de aplicación, que a su vez genera una Transaction).
11. **PredictionValue** — ya era `nvarchar(10)` con valores `yes`/`no`; normalizado a catálogo `PredictionOptions`.
12. **Predictions** — los campos de resultado (`isWinner`, `pointsEarned`, `moneyEarned`) se mueven a `PredictionResults`; la predicción original es inmutable una vez cerrada.
13. **Propositions** — campos de AI (`aiReviewStatus`, `aiReviewAt`, `aiBlockReason`) delegados al job correspondiente en `AIAnalysisJobs`. La proposición solo guarda `aiJobId`.
14. **SocialAccounts tokens** — `accessToken`/`refreshToken` movidos a `SocialAccountTokens` con historial de rotaciones.
15. **Points / PointsBalance / moneyBalance en Players eliminados** — reemplazados por `Wallets`.

---

# Tables

---

## Catálogos de Statuses y Types

### TransactionTypes
Catálogo normalizado de tipos de transacción.

- transactionTypeId
    - tipo: int identity
    - pk: si
    - null: no
    - descripcion: Identificador del tipo de transacción

- code
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: Código único del tipo (deposit, withdrawal, wager, reward, commission, penalty, points_purchase, points_redemption, refund)
    - constraint: UNIQUE

- description
    - tipo: nvarchar(200)
    - pk: no
    - null: no
    - descripcion: Descripción legible del tipo

- isDebit
    - tipo: bit
    - pk: no
    - null: no
    - default: 1
    - descripcion: 1 = resta del balance, 0 = suma al balance

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

### PropositionStatuses
Catálogo de estados de proposición.

- propositionStatusId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: Código del estado (pending_ai, pending_vote, pending_acceptance, active, closed, validated, cancelled, rejected_ai, rejected_subject)
    - constraint: UNIQUE

- description
    - tipo: nvarchar(200)
    - pk: no
    - null: no

---

### PlayerStatuses
Catálogo de estados de jugador.

- playerStatusId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: active, suspended, banned, inactive
    - constraint: UNIQUE

- description
    - tipo: nvarchar(200)
    - pk: no
    - null: no

---

### PropositionOutcomes
Catálogo de resultados finales de proposición.

- outcomeId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(20)
    - pk: no
    - null: no
    - descripcion: yes, no, cancelled, unresolvable
    - constraint: UNIQUE

- description
    - tipo: nvarchar(200)
    - pk: no
    - null: no

---

### PredictionOptions
Catálogo de valores de predicción (yes/no).

- predictionOptionId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(10)
    - pk: no
    - null: no
    - descripcion: yes, no
    - constraint: UNIQUE

---

### AIJobTypes
Catálogo de tipos de análisis de AI.

- aiJobTypeId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: content_moderation, evidence_validation, outcome_detection, manipulation_detection
    - constraint: UNIQUE

- description
    - tipo: nvarchar(200)
    - pk: no
    - null: no

---

### AIJobStatuses
Catálogo de estados de jobs de AI.

- aiJobStatusId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(20)
    - pk: no
    - null: no
    - descripcion: queued, running, completed, failed, cancelled
    - constraint: UNIQUE

---

### PenaltyCatalog
Catálogo de tipos de penalización con configuración que cambia en el tiempo.

- penaltyCatalogId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: proposition_rejection, unresolvable_evidence, abuse, false_evidence, late_validation
    - constraint: UNIQUE

- description
    - tipo: nvarchar(500)
    - pk: no
    - null: no

- penaltyPercentage
    - tipo: decimal(5,2)
    - pk: no
    - null: si
    - default: NULL
    - descripcion: Porcentaje de puntos a deducir del balance actual (ej. 15.00 = 15%). NULL si es monto fijo.

- fixedPointsAmount
    - tipo: bigint
    - pk: no
    - null: si
    - default: NULL
    - descripcion: Monto fijo de puntos a deducir. NULL si es porcentaje.

- effectiveFrom
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()
    - descripcion: Inicio de vigencia de esta configuración

- effectiveTo
    - tipo: datetime2
    - pk: no
    - null: si
    - default: NULL
    - descripcion: Fin de vigencia. NULL = vigente actualmente.

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## MediaTypes

- mediaTypeId
    - tipo: int identity
    - pk: si
    - null: no

- mimeType
    - tipo: nvarchar(100)
    - pk: no
    - null: no
    - descripcion: Ej. image/png, video/mp4
    - constraint: UNIQUE

- mediaExtension
    - tipo: nvarchar(10)
    - pk: no
    - null: no

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## Files

- fileId
    - tipo: bigint identity
    - pk: si
    - null: no

- mediaTypeId
    - tipo: int
    - pk: no
    - null: no
    - fk: MediaTypes.mediaTypeId

- fileName
    - tipo: nvarchar(255)
    - pk: no
    - null: no

- fileURL
    - tipo: nvarchar(1000)
    - pk: no
    - null: no

- fileSize
    - tipo: bigint
    - pk: no
    - null: si

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- deletedAt
    - tipo: datetime2
    - pk: no
    - null: si

---

## Countries

- countryId
    - tipo: int identity
    - pk: si
    - null: no

- countryName
    - tipo: nvarchar(100)
    - pk: no
    - null: no

- isoCode
    - tipo: char(3)
    - pk: no
    - null: no
    - constraint: UNIQUE

- flagFileId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Files.fileId

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## Currencies
Incluye monedas reales Y puntos virtuales. Los puntos son una Currency con código `PTS`.

- currencyId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: char(10)
    - pk: no
    - null: no
    - descripcion: ISO 4217 para dinero real (USD, CRC, EUR) o código interno para virtuales (PTS)
    - constraint: UNIQUE

- currencyName
    - tipo: nvarchar(100)
    - pk: no
    - null: no

- symbol
    - tipo: nvarchar(10)
    - pk: no
    - null: no

- isVirtual
    - tipo: bit
    - pk: no
    - null: no
    - default: 0
    - descripcion: 1 = moneda virtual de la plataforma (puntos), 0 = dinero real

- decimalPlaces
    - tipo: tinyint
    - pk: no
    - null: no
    - default: 2
    - descripcion: 0 para puntos (enteros), 2 para dinero real

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## Players

- playerId
    - tipo: bigint identity
    - pk: si
    - null: no

- username
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - constraint: UNIQUE

- email
    - tipo: nvarchar(255)
    - pk: no
    - null: no
    - constraint: UNIQUE

- passwordHash
    - tipo: varbinary(64)
    - pk: no
    - null: no
    - descripcion: Hash bcrypt/SHA-512 de la contraseña

- passwordSalt
    - tipo: varbinary(32)
    - pk: no
    - null: no
    - descripcion: Salt único por jugador

- avatarFileId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Files.fileId

- playerStatusId
    - tipo: int
    - pk: no
    - null: no
    - fk: PlayerStatuses.playerStatusId
    - default: (id de 'active')

- countryId
    - tipo: int
    - pk: no
    - null: si
    - fk: Countries.countryId

- isVerified
    - tipo: bit
    - pk: no
    - null: no
    - default: 0

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- deletedAt
    - tipo: datetime2
    - pk: no
    - null: si

---

## Wallets
Un jugador tiene una wallet por cada Currency activa (al menos PTS y una moneda real). Unifica puntos y dinero.

- walletId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- currencyId
    - tipo: int
    - pk: no
    - null: no
    - fk: Currencies.currencyId

- balance
    - tipo: decimal(18,4)
    - pk: no
    - null: no
    - default: 0
    - descripcion: Saldo disponible. Para puntos virtuales (isVirtual=1) el valor es siempre entero.

- reservedBalance
    - tipo: decimal(18,4)
    - pk: no
    - null: no
    - default: 0
    - descripcion: Monto reservado pendiente de resolución (ej. puntos apostados en proposición activa)

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- updatedAt
    - tipo: datetime2
    - pk: no
    - null: si

- constraint: UNIQUE (playerId, currencyId)

---

## PlatformConfig
Configuración de la plataforma con vigencia temporal. Para saber el valor actual se busca el registro donde `effectiveFrom <= NOW() AND (effectiveTo IS NULL OR effectiveTo > NOW())`.

- configId
    - tipo: int identity
    - pk: si
    - null: no

- welcomePoints
    - tipo: bigint
    - pk: no
    - null: no
    - default: 100
    - descripcion: Puntos otorgados al registrarse

- minPointsReserveForProposition
    - tipo: bigint
    - pk: no
    - null: no
    - descripcion: Mínimo de puntos que debe tener el jugador para poder crear una proposición (cubre posible penalización)

- platformPointsCommissionPct
    - tipo: decimal(5,2)
    - pk: no
    - null: no
    - descripcion: % de comisión de la plataforma sobre el pozo de puntos

- platformMoneyCommissionPct
    - tipo: decimal(5,2)
    - pk: no
    - null: no
    - descripcion: % de comisión de la plataforma sobre el pozo de dinero real

- proposerPointsCommissionPct
    - tipo: decimal(5,2)
    - pk: no
    - null: no
    - descripcion: % de comisión para el creador de la proposición

- streakBonusMultiplier
    - tipo: decimal(5,2)
    - pk: no
    - null: no
    - default: 1.00

- effectiveFrom
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- effectiveTo
    - tipo: datetime2
    - pk: no
    - null: si
    - default: NULL

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- createdBy
    - tipo: bigint
    - pk: no
    - null: si
    - descripcion: Admin que creó esta configuración

---

## Transactions
Patrón de transacciones unificado para puntos y dinero. Inmutable una vez creada.

- transactionId
    - tipo: bigint identity
    - pk: si
    - null: no

- walletId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Wallets.walletId

- transactionTypeId
    - tipo: int
    - pk: no
    - null: no
    - fk: TransactionTypes.transactionTypeId

- amount
    - tipo: decimal(18,4)
    - pk: no
    - null: no
    - descripcion: Positivo = crédito al wallet, negativo = débito

- balanceBefore
    - tipo: decimal(18,4)
    - pk: no
    - null: no

- balanceAfter
    - tipo: decimal(18,4)
    - pk: no
    - null: no

- referenceType
    - tipo: nvarchar(50)
    - pk: no
    - null: si
    - descripcion: Entidad origen: proposition, prediction, penalty, payment_attempt, redemption

- referenceId
    - tipo: bigint
    - pk: no
    - null: si

- correlationId
    - tipo: uniqueidentifier
    - pk: no
    - null: si
    - default: NEWID()
    - descripcion: Agrupa transacciones del mismo evento de negocio (ej. distribución de premios de una proposición)

- description
    - tipo: nvarchar(500)
    - pk: no
    - null: si

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## TransactionDetails
Metadata adicional de transacciones que requieren detalle (ej. withdrawal: datos bancarios usados).

- detailId
    - tipo: bigint identity
    - pk: si
    - null: no

- transactionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Transactions.transactionId
    - constraint: UNIQUE

- paymentMethodId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: PaymentMethods.paymentMethodId
    - descripcion: Método de pago usado (para deposits y withdrawals)

- providerReference
    - tipo: nvarchar(255)
    - pk: no
    - null: si
    - descripcion: Referencia del gateway externo

- metadata
    - tipo: nvarchar(max)
    - pk: no
    - null: si
    - descripcion: JSON con datos extra según el tipo de transacción

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## PlayerDevices
Almacena dispositivos y user-agents de sesiones para análisis de seguridad.

- deviceId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- userAgentRaw
    - tipo: nvarchar(1000)
    - pk: no
    - null: no
    - descripcion: Cadena completa del User-Agent

- browser
    - tipo: nvarchar(100)
    - pk: no
    - null: si

- os
    - tipo: nvarchar(100)
    - pk: no
    - null: si

- deviceType
    - tipo: nvarchar(50)
    - pk: no
    - null: si
    - descripcion: mobile, desktop, tablet

- firstSeenAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- lastSeenAt
    - tipo: datetime2
    - pk: no
    - null: si

---

## PlayerSessions

- sessionId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- deviceId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: PlayerDevices.deviceId

- sessionTokenHash
    - tipo: char(64)
    - pk: no
    - null: no
    - descripcion: SHA-256 hex del token JWT. No se guarda el token completo, solo su hash para revocación.
    - constraint: UNIQUE

- ipAddress
    - tipo: nvarchar(45)
    - pk: no
    - null: si

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- expiresAt
    - tipo: datetime2
    - pk: no
    - null: no

- revokedAt
    - tipo: datetime2
    - pk: no
    - null: si

---

## SocialPlatforms
Catálogo de redes sociales soportadas.

- platformId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: instagram, tiktok, twitter, youtube
    - constraint: UNIQUE

- displayName
    - tipo: nvarchar(100)
    - pk: no
    - null: no

- isActive
    - tipo: bit
    - pk: no
    - null: no
    - default: 1

---

## SocialAccounts
Cuenta social vinculada a un jugador. No guarda tokens directamente.

- socialAccountId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- platformId
    - tipo: int
    - pk: no
    - null: no
    - fk: SocialPlatforms.platformId

- externalUserId
    - tipo: nvarchar(255)
    - pk: no
    - null: no
    - descripcion: ID del usuario en la plataforma social externa

- username
    - tipo: nvarchar(100)
    - pk: no
    - null: no

- profileURL
    - tipo: nvarchar(1000)
    - pk: no
    - null: si

- linkedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- unlinkedAt
    - tipo: datetime2
    - pk: no
    - null: si

- constraint: UNIQUE (playerId, platformId)

---

## SocialAccountTokens
Historial de tokens OAuth. Los tokens rotan; cada refresh genera un nuevo registro.

- tokenId
    - tipo: bigint identity
    - pk: si
    - null: no

- socialAccountId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: SocialAccounts.socialAccountId

- accessTokenEncrypted
    - tipo: varbinary(max)
    - pk: no
    - null: no
    - descripcion: Token cifrado con la master key de SQL Server

- refreshTokenEncrypted
    - tipo: varbinary(max)
    - pk: no
    - null: si

- scopes
    - tipo: nvarchar(1000)
    - pk: no
    - null: si
    - descripcion: Lista de scopes concedidos, separados por espacio

- issuedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- expiresAt
    - tipo: datetime2
    - pk: no
    - null: si

- revokedAt
    - tipo: datetime2
    - pk: no
    - null: si
    - descripcion: NULL = token vigente

- revokedReason
    - tipo: nvarchar(100)
    - pk: no
    - null: si
    - descripcion: refresh, user_unlink, revoked_by_platform

---

## SocialContentCache

- contentCacheId
    - tipo: bigint identity
    - pk: si
    - null: no

- socialAccountId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: SocialAccounts.socialAccountId

- externalContentId
    - tipo: nvarchar(255)
    - pk: no
    - null: no

- contentType
    - tipo: nvarchar(30)
    - pk: no
    - null: no
    - descripcion: post, story, reel, video, image

- contentURL
    - tipo: nvarchar(1000)
    - pk: no
    - null: si

- caption
    - tipo: nvarchar(2000)
    - pk: no
    - null: si

- rawMetadata
    - tipo: nvarchar(max)
    - pk: no
    - null: si
    - descripcion: JSON completo devuelto por la API externa

- publishedAt
    - tipo: datetime2
    - pk: no
    - null: si

- fetchedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- expiresAt
    - tipo: datetime2
    - pk: no
    - null: si
    - descripcion: Momento en que se debe refrescar el caché

- constraint: UNIQUE (socialAccountId, externalContentId)

---

## AIProviders
Catálogo de proveedores de AI (Anthropic, OpenAI, Google, etc).

- providerId
    - tipo: int identity
    - pk: si
    - null: no

- code
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: anthropic, openai, google, mistral
    - constraint: UNIQUE

- displayName
    - tipo: nvarchar(100)
    - pk: no
    - null: no

- apiBaseURL
    - tipo: nvarchar(500)
    - pk: no
    - null: si

- isActive
    - tipo: bit
    - pk: no
    - null: no
    - default: 1

---

## AIModels
Modelos específicos de cada proveedor, con vigencia para rotación.

- modelId
    - tipo: int identity
    - pk: si
    - null: no

- providerId
    - tipo: int
    - pk: no
    - null: no
    - fk: AIProviders.providerId

- modelCode
    - tipo: nvarchar(100)
    - pk: no
    - null: no
    - descripcion: claude-3-5-sonnet-20241022, gpt-4o, gemini-1.5-pro, etc.

- displayName
    - tipo: nvarchar(200)
    - pk: no
    - null: no

- effectiveFrom
    - tipo: datetime2
    - pk: no
    - null: no

- effectiveTo
    - tipo: datetime2
    - pk: no
    - null: si
    - descripcion: NULL = modelo actualmente disponible

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## AIAnalysisJobs
Registro de cada solicitud enviada a un modelo de AI. Inmutable.

- jobId
    - tipo: bigint identity
    - pk: si
    - null: no

- aiJobTypeId
    - tipo: int
    - pk: no
    - null: no
    - fk: AIJobTypes.aiJobTypeId

- modelId
    - tipo: int
    - pk: no
    - null: no
    - fk: AIModels.modelId
    - descripcion: Modelo específico que procesó este job

- referenceType
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: proposition, evidence, social_content

- referenceId
    - tipo: bigint
    - pk: no
    - null: no

- aiJobStatusId
    - tipo: int
    - pk: no
    - null: no
    - fk: AIJobStatuses.aiJobStatusId
    - default: (id de 'queued')

- inputPayload
    - tipo: nvarchar(max)
    - pk: no
    - null: no
    - descripcion: JSON exacto enviado al modelo (prompt, contexto, parámetros)

- promptVersion
    - tipo: nvarchar(50)
    - pk: no
    - null: si
    - descripcion: Versión del prompt template utilizado (para trazabilidad de cambios en prompts)

- startedAt
    - tipo: datetime2
    - pk: no
    - null: si

- completedAt
    - tipo: datetime2
    - pk: no
    - null: si

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## AIAnalysisResults
Respuesta del modelo para un job. Separado del job para mantener el job inmutable y permitir reintentos.

- resultId
    - tipo: bigint identity
    - pk: si
    - null: no

- jobId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: AIAnalysisJobs.jobId

- outputPayload
    - tipo: nvarchar(max)
    - pk: no
    - null: no
    - descripcion: JSON completo de la respuesta del modelo

- decision
    - tipo: nvarchar(50)
    - pk: no
    - null: si
    - descripcion: Decisión estructurada extraída del output (approved, rejected, flagged, outcome_yes, outcome_no, ambiguous)

- confidenceScore
    - tipo: decimal(5,4)
    - pk: no
    - null: si

- flags
    - tipo: nvarchar(500)
    - pk: no
    - null: si
    - descripcion: JSON array de categorías detectadas (violence, sexual, illegal, discriminatory)

- errorMessage
    - tipo: nvarchar(1000)
    - pk: no
    - null: si

- tokensUsed
    - tipo: int
    - pk: no
    - null: si
    - descripcion: Tokens consumidos en la llamada (para monitoreo de costos)

- latencyMs
    - tipo: int
    - pk: no
    - null: si
    - descripcion: Latencia de la llamada al API en milisegundos

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## Propositions

- propositionId
    - tipo: bigint identity
    - pk: si
    - null: no

- creatorId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- subjectPlayerId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Players.playerId

- propositionText
    - tipo: nvarchar(1000)
    - pk: no
    - null: no

- propositionStatusId
    - tipo: int
    - pk: no
    - null: no
    - fk: PropositionStatuses.propositionStatusId

- aiJobId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: AIAnalysisJobs.jobId
    - descripcion: Job de moderación de contenido que revisó esta proposición

- winningVoteId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: PropositionVotes.voteId

- acceptedAt
    - tipo: datetime2
    - pk: no
    - null: si

- predictionsCloseAt
    - tipo: datetime2
    - pk: no
    - null: si

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## PropositionVotes

- voteId
    - tipo: bigint identity
    - pk: si
    - null: no

- propositionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Propositions.propositionId

- voterId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- voteValue
    - tipo: nvarchar(10)
    - pk: no
    - null: no
    - descripcion: yes / no — indica si el votante cree que la proposición ocurrirá

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- constraint: UNIQUE (propositionId, voterId)

---

## PropositionEvents
Log de cambios de estado de proposición. Solo inserts.

- eventId
    - tipo: bigint identity
    - pk: si
    - null: no

- propositionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Propositions.propositionId

- fromStatusId
    - tipo: int
    - pk: no
    - null: si
    - fk: PropositionStatuses.propositionStatusId

- toStatusId
    - tipo: int
    - pk: no
    - null: no
    - fk: PropositionStatuses.propositionStatusId

- triggeredBy
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Players.playerId
    - descripcion: NULL si fue un proceso automático

- notes
    - tipo: nvarchar(500)
    - pk: no
    - null: si

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## PropositionOutcomeRecords
Resultado final validado de una proposición. Separado para no mutar Propositions.

- outcomeRecordId
    - tipo: bigint identity
    - pk: si
    - null: no

- propositionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Propositions.propositionId
    - constraint: UNIQUE

- outcomeId
    - tipo: int
    - pk: no
    - null: no
    - fk: PropositionOutcomes.outcomeId

- validationJobId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: AIAnalysisJobs.jobId
    - descripcion: Job de AI que determinó el outcome

- validatedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- validatedBy
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Players.playerId
    - descripcion: NULL si fue validación automática por AI

---

## Predictions

- predictionId
    - tipo: bigint identity
    - pk: si
    - null: no

- propositionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Propositions.propositionId

- predictorId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- predictionOptionId
    - tipo: int
    - pk: no
    - null: no
    - fk: PredictionOptions.predictionOptionId

- walletId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Wallets.walletId
    - descripcion: Wallet debitada al apostar (define si es puntos o dinero real)

- amountWagered
    - tipo: decimal(18,4)
    - pk: no
    - null: no

- lockedAt
    - tipo: datetime2
    - pk: no
    - null: si
    - descripcion: Momento en que la predicción quedó bloqueada

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- constraint: UNIQUE (propositionId, predictorId, walletId)

---

## PredictionWagerHistory
Registra cada incremento de apuesta antes del cierre. Inmutable.

- wagerId
    - tipo: bigint identity
    - pk: si
    - null: no

- predictionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Predictions.predictionId

- additionalAmount
    - tipo: decimal(18,4)
    - pk: no
    - null: no

- totalAfter
    - tipo: decimal(18,4)
    - pk: no
    - null: no

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## PredictionResults
Resultado de una predicción tras validarse la proposición. Separado de Predictions para no mutarla.

- resultId
    - tipo: bigint identity
    - pk: si
    - null: no

- predictionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Predictions.predictionId
    - constraint: UNIQUE

- isWinner
    - tipo: bit
    - pk: no
    - null: no

- amountEarned
    - tipo: decimal(18,4)
    - pk: no
    - null: no
    - default: 0

- transactionId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Transactions.transactionId
    - descripcion: Transacción de pago del premio

- resolvedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## EvidenceSubmissions

- evidenceId
    - tipo: bigint identity
    - pk: si
    - null: no

- propositionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Propositions.propositionId

- submittedBy
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- socialAccountId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: SocialAccounts.socialAccountId

- fileId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Files.fileId

- socialContentCacheId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: SocialContentCache.contentCacheId

- hasGathelHashtag
    - tipo: bit
    - pk: no
    - null: no
    - default: 0

- aiJobId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: AIAnalysisJobs.jobId

- manualReviewRequired
    - tipo: bit
    - pk: no
    - null: no
    - default: 0

- submittedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## RewardDistributions
Registro de cada crédito de premio/comisión por proposición. Inmutable.

- distributionId
    - tipo: bigint identity
    - pk: si
    - null: no

- propositionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Propositions.propositionId

- transactionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Transactions.transactionId

- distributionTypeId
    - tipo: int
    - pk: no
    - null: no
    - fk: TransactionTypes.transactionTypeId
    - descripcion: winner_reward, commission_platform, commission_proposer

- percentageShare
    - tipo: decimal(5,2)
    - pk: no
    - null: si

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## PenaltyTransactions
Registro de cada penalización aplicada. Genera una Transaction.

- penaltyTxId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- penaltyCatalogId
    - tipo: int
    - pk: no
    - null: no
    - fk: PenaltyCatalog.penaltyCatalogId
    - descripcion: Define el tipo y % aplicado en el momento de la penalización

- propositionId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Propositions.propositionId

- transactionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Transactions.transactionId
    - descripcion: Transacción de débito generada por esta penalización

- pointsDeducted
    - tipo: bigint
    - pk: no
    - null: no
    - descripcion: Monto real deducido (calculado en el momento de aplicar la penalización)

- notes
    - tipo: nvarchar(500)
    - pk: no
    - null: si

- appliedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## PaymentMethods

- paymentMethodId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- countryId
    - tipo: int
    - pk: no
    - null: si
    - fk: Countries.countryId

- currencyId
    - tipo: int
    - pk: no
    - null: si
    - fk: Currencies.currencyId

- methodType
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: credit_card, debit_card, bank_transfer, sinpe, paypal

- alias
    - tipo: nvarchar(100)
    - pk: no
    - null: si

- accountDetailsEncrypted
    - tipo: varbinary(max)
    - pk: no
    - null: si
    - descripcion: Datos cifrados (últimos 4 dígitos, IBAN, etc.)

- isVerified
    - tipo: bit
    - pk: no
    - null: no
    - default: 0

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- deletedAt
    - tipo: datetime2
    - pk: no
    - null: si

---

## PaymentAttempts

- paymentAttemptId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- paymentMethodId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: PaymentMethods.paymentMethodId

- transactionId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Transactions.transactionId

- attemptTypeId
    - tipo: int
    - pk: no
    - null: no
    - fk: TransactionTypes.transactionTypeId
    - descripcion: deposit, withdrawal, points_purchase

- amount
    - tipo: decimal(18,4)
    - pk: no
    - null: no

- currencyId
    - tipo: int
    - pk: no
    - null: no
    - fk: Currencies.currencyId

- status
    - tipo: nvarchar(20)
    - pk: no
    - null: no
    - default: 'pending'
    - descripcion: pending, success, failed, cancelled

- providerReference
    - tipo: nvarchar(255)
    - pk: no
    - null: si

- errorMessage
    - tipo: nvarchar(500)
    - pk: no
    - null: si

- attemptedAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- resolvedAt
    - tipo: datetime2
    - pk: no
    - null: si

---

## AuditLog
Patrón de log de auditoría. Solo inserts, nunca updates. Optimizado para alto volumen.

- auditId
    - tipo: bigint identity
    - pk: si
    - null: no

- entityName
    - tipo: nvarchar(100)
    - pk: no
    - null: no
    - descripcion: Nombre de la tabla/entidad afectada

- entityId
    - tipo: nvarchar(50)
    - pk: no
    - null: no
    - descripcion: PK del registro afectado

- operation
    - tipo: char(6)
    - pk: no
    - null: no
    - descripcion: INSERT, UPDATE, DELETE

- performedBy
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Players.playerId
    - descripcion: NULL si fue proceso del sistema

- sessionId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: PlayerSessions.sessionId

- correlationId
    - tipo: uniqueidentifier
    - pk: no
    - null: si
    - descripcion: Para agrupar eventos del mismo flujo de negocio

- ipAddress
    - tipo: nvarchar(45)
    - pk: no
    - null: si

- oldSnapshot
    - tipo: nvarchar(max)
    - pk: no
    - null: si
    - descripcion: JSON del estado anterior del registro (NULL en INSERTs)

- newSnapshot
    - tipo: nvarchar(max)
    - pk: no
    - null: si
    - descripcion: JSON del nuevo estado del registro (NULL en DELETEs)

- occurredAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

---

## AffiliatePartners

- partnerId
    - tipo: int identity
    - pk: si
    - null: no

- partnerName
    - tipo: nvarchar(100)
    - pk: no
    - null: no

- countryId
    - tipo: int
    - pk: no
    - null: si
    - fk: Countries.countryId

- logoFileId
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Files.fileId

- websiteURL
    - tipo: nvarchar(1000)
    - pk: no
    - null: si

- isActive
    - tipo: bit
    - pk: no
    - null: no
    - default: 1

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()

- createdBy
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId
    - descripcion: Admin que registró el partner

- updatedAt
    - tipo: datetime2
    - pk: no
    - null: si

- updatedBy
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Players.playerId
    - descripcion: Admin que realizó la última modificación

- deletedAt
    - tipo: datetime2
    - pk: no
    - null: si

- deletedBy
    - tipo: bigint
    - pk: no
    - null: si
    - fk: Players.playerId
    - descripcion: Admin que realizó el soft delete

---

## PointsRedemptions

- redemptionId
    - tipo: bigint identity
    - pk: si
    - null: no

- playerId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Players.playerId

- partnerId
    - tipo: int
    - pk: no
    - null: no
    - fk: AffiliatePartners.partnerId

- transactionId
    - tipo: bigint
    - pk: no
    - null: no
    - fk: Transactions.transactionId
    - descripcion: Transacción de débito de puntos generada por esta redención

- pointsSpent
    - tipo: bigint
    - pk: no
    - null: no

- rewardDetail
    - tipo: nvarchar(500)
    - pk: no
    - null: si

- status
    - tipo: nvarchar(20)
    - pk: no
    - null: no
    - default: 'pending'
    - descripcion: pending, completed, rejected, expired

- createdAt
    - tipo: datetime2
    - pk: no
    - null: no
    - default: GETUTCDATE()
