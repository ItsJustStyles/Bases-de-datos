-- ==============================================================================
-- 1. TABLAS DE CATÁLOGOS INDEPENDIENTES Y MEDIA
-- ==============================================================================

CREATE TABLE TransactionTypes (
    transactionTypeId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL,
    description NVARCHAR(200) NOT NULL,
    isDebit BIT NOT NULL DEFAULT 1, -- 1 = resta del balance, 0 = suma al balance
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_TransactionTypes PRIMARY KEY (transactionTypeId),
    CONSTRAINT UQ_TransactionTypes_Code UNIQUE (code)
);

CREATE TABLE PropositionStatuses (
    propositionStatusId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL, -- pending_ai, pending_vote, active, closed, etc.
    description NVARCHAR(200) NOT NULL,
    CONSTRAINT PK_PropositionStatuses PRIMARY KEY (propositionStatusId),
    CONSTRAINT UQ_PropositionStatuses_Code UNIQUE (code)
);

CREATE TABLE PlayerStatuses (
    playerStatusId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL, -- active, suspended, banned, inactive
    description NVARCHAR(200) NOT NULL,
    CONSTRAINT PK_PlayerStatuses PRIMARY KEY (playerStatusId),
    CONSTRAINT UQ_PlayerStatuses_Code UNIQUE (code)
);

CREATE TABLE PropositionOutcomes (
    outcomeId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(20) NOT NULL, -- yes, no, cancelled, unresolvable
    description NVARCHAR(200) NOT NULL,
    CONSTRAINT PK_PropositionOutcomes PRIMARY KEY (outcomeId),
    CONSTRAINT UQ_PropositionOutcomes_Code UNIQUE (code)
);

CREATE TABLE PredictionOptions (
    predictionOptionId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(10) NOT NULL, -- yes, no
    CONSTRAINT PK_PredictionOptions PRIMARY KEY (predictionOptionId),
    CONSTRAINT UQ_PredictionOptions_Code UNIQUE (code)
);

CREATE TABLE AIJobTypes (
    aiJobTypeId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL, -- content_moderation, evidence_validation, etc.
    description NVARCHAR(200) NOT NULL,
    CONSTRAINT PK_AIJobTypes PRIMARY KEY (aiJobTypeId),
    CONSTRAINT UQ_AIJobTypes_Code UNIQUE (code)
);

CREATE TABLE AIJobStatuses (
    aiJobStatusId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(20) NOT NULL, -- queued, running, completed, failed, cancelled
    CONSTRAINT PK_AIJobStatuses PRIMARY KEY (aiJobStatusId),
    CONSTRAINT UQ_AIJobStatuses_Code UNIQUE (code)
);

CREATE TABLE PenaltyCatalog (
    penaltyCatalogId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL, -- proposition_rejection, false_evidence, etc.
    description NVARCHAR(500) NOT NULL,
    penaltyPercentage DECIMAL(5,2) NULL DEFAULT NULL, -- Porcentaje de puntos a deducir
    fixedPointsAmount BIGINT NULL DEFAULT NULL, -- Monto fijo de puntos a deducir
    effectiveFrom DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    effectiveTo DATETIME2 NULL DEFAULT NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PenaltyCatalog PRIMARY KEY (penaltyCatalogId),
    CONSTRAINT UQ_PenaltyCatalog_Code UNIQUE (code)
);

CREATE TABLE MediaTypes (
    mediaTypeId INT IDENTITY(1,1) NOT NULL,
    mimeType NVARCHAR(100) NOT NULL, -- Ej. image/png, video/mp4
    mediaExtension NVARCHAR(10) NOT NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_MediaTypes PRIMARY KEY (mediaTypeId),
    CONSTRAINT UQ_MediaTypes_MimeType UNIQUE (mimeType)
);

CREATE TABLE SocialPlatforms (
    platformId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL, -- instagram, tiktok, twitter, youtube
    displayName NVARCHAR(100) NOT NULL,
    isActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_SocialPlatforms PRIMARY KEY (platformId),
    CONSTRAINT UQ_SocialPlatforms_Code UNIQUE (code)
);

CREATE TABLE AIProviders (
    providerId INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL, -- anthropic, openai, google, mistral
    displayName NVARCHAR(100) NOT NULL,
    apiBaseURL NVARCHAR(500) NULL,
    isActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_AIProviders PRIMARY KEY (providerId),
    CONSTRAINT UQ_AIProviders_Code UNIQUE (code)
);

-- ==============================================================================
-- 2. TABLAS DEL CORE DE ARCHIVOS, GEOGRAFÍA Y DIVISAS
-- ==============================================================================

CREATE TABLE Files (
    fileId BIGINT IDENTITY(1,1) NOT NULL,
    mediaTypeId INT NOT NULL,
    fileName NVARCHAR(255) NOT NULL,
    fileURL NVARCHAR(1000) NOT NULL,
    fileSize BIGINT NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    deletedAt DATETIME2 NULL,
    CONSTRAINT PK_Files PRIMARY KEY (fileId),
    CONSTRAINT FK_Files_MediaTypes FOREIGN KEY (mediaTypeId) REFERENCES MediaTypes(mediaTypeId)
);

CREATE TABLE Countries (
    countryId INT IDENTITY(1,1) NOT NULL,
    countryName NVARCHAR(100) NOT NULL,
    isoCode CHAR(3) NOT NULL,
    flagFileId BIGINT NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Countries PRIMARY KEY (countryId),
    CONSTRAINT UQ_Countries_IsoCode UNIQUE (isoCode),
    CONSTRAINT FK_Countries_Files FOREIGN KEY (flagFileId) REFERENCES Files(fileId)
);

CREATE TABLE Currencies (
    currencyId INT IDENTITY(1,1) NOT NULL,
    code CHAR(10) NOT NULL, -- ISO 4217 o virtuales (PTS)
    currencyName NVARCHAR(100) NOT NULL,
    symbol NVARCHAR(10) NOT NULL,
    isVirtual BIT NOT NULL DEFAULT 0, -- 1 = puntos de la plataforma
    decimalPlaces TINYINT NOT NULL DEFAULT 2, -- 0 para puntos, 2 para dinero real
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Currencies PRIMARY KEY (currencyId),
    CONSTRAINT UQ_Currencies_Code UNIQUE (code)
);

-- ==============================================================================
-- 3. JUGADORES, WALLETS Y SEGURIDAD DISPOSITIVOS
-- ==============================================================================

CREATE TABLE Players (
    playerId BIGINT IDENTITY(1,1) NOT NULL,
    username NVARCHAR(50) NOT NULL,
    email NVARCHAR(255) NOT NULL,
    passwordHash VARBINARY(64) NOT NULL, -- Hash SHA-512 / bcrypt
    passwordSalt VARBINARY(32) NOT NULL, -- Salt único
    avatarFileId BIGINT NULL,
    playerStatusId INT NOT NULL,
    countryId INT NULL,
    isVerified BIT NOT NULL DEFAULT 0,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    deletedAt DATETIME2 NULL,
    CONSTRAINT PK_Players PRIMARY KEY (playerId),
    CONSTRAINT UQ_Players_Username UNIQUE (username),
    CONSTRAINT UQ_Players_Email UNIQUE (email),
    CONSTRAINT FK_Players_Files FOREIGN KEY (avatarFileId) REFERENCES Files(fileId),
    CONSTRAINT FK_Players_PlayerStatuses FOREIGN KEY (playerStatusId) REFERENCES PlayerStatuses(playerStatusId),
    CONSTRAINT FK_Players_Countries FOREIGN KEY (countryId) REFERENCES Countries(countryId)
);

CREATE TABLE Wallets (
    walletId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    currencyId INT NOT NULL,
    balance DECIMAL(18,4) NOT NULL DEFAULT 0,
    reservedBalance DECIMAL(18,4) NOT NULL DEFAULT 0,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updatedAt DATETIME2 NULL,
    CONSTRAINT PK_Wallets PRIMARY KEY (walletId),
    CONSTRAINT UQ_Wallets_Player_Currency UNIQUE (playerId, currencyId),
    CONSTRAINT FK_Wallets_Players FOREIGN KEY (playerId) REFERENCES Players(playerId),
    CONSTRAINT FK_Wallets_Currencies FOREIGN KEY (currencyId) REFERENCES Currencies(currencyId)
);

CREATE TABLE PlatformConfig (
    configId INT IDENTITY(1,1) NOT NULL,
    welcomePoints BIGINT NOT NULL DEFAULT 100,
    minPointsReserveForProposition BIGINT NOT NULL,
    platformPointsCommissionPct DECIMAL(5,2) NOT NULL,
    platformMoneyCommissionPct DECIMAL(5,2) NOT NULL,
    proposerPointsCommissionPct DECIMAL(5,2) NOT NULL,
    streakBonusMultiplier DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    effectiveFrom DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    effectiveTo DATETIME2 NULL DEFAULT NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    createdBy BIGINT NULL, -- Admin/Player que creó la config
    CONSTRAINT PK_PlatformConfig PRIMARY KEY (configId),
    CONSTRAINT FK_PlatformConfig_Players FOREIGN KEY (createdBy) REFERENCES Players(playerId)
);

CREATE TABLE PlayerDevices (
    deviceId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    userAgentRaw NVARCHAR(1000) NOT NULL,
    browser NVARCHAR(100) NULL,
    os NVARCHAR(100) NULL,
    deviceType NVARCHAR(50) NULL, -- mobile, desktop, tablet
    firstSeenAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    lastSeenAt DATETIME2 NULL,
    CONSTRAINT PK_PlayerDevices PRIMARY KEY (deviceId),
    CONSTRAINT FK_PlayerDevices_Players FOREIGN KEY (playerId) REFERENCES Players(playerId)
);

CREATE TABLE PlayerSessions (
    sessionId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    deviceId BIGINT NULL,
    sessionTokenHash CHAR(64) NOT NULL, -- SHA-256 en hex del token JWT
    ipAddress NVARCHAR(45) NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    expiresAt DATETIME2 NOT NULL,
    revokedAt DATETIME2 NULL,
    CONSTRAINT PK_PlayerSessions PRIMARY KEY (sessionId),
    CONSTRAINT UQ_PlayerSessions_TokenHash UNIQUE (sessionTokenHash),
    CONSTRAINT FK_PlayerSessions_Players FOREIGN KEY (playerId) REFERENCES Players(playerId),
    CONSTRAINT FK_PlayerSessions_PlayerDevices FOREIGN KEY (deviceId) REFERENCES PlayerDevices(deviceId)
);

-- ==============================================================================
-- 4. CAPA TRANSACCIONAL Y PASARELAS DE PAGO
-- ==============================================================================

CREATE TABLE Transactions (
    transactionId BIGINT IDENTITY(1,1) NOT NULL,
    walletId BIGINT NOT NULL,
    transactionTypeId INT NOT NULL,
    amount DECIMAL(18,4) NOT NULL, -- Positivo = crédito, Negativo = débito
    balanceBefore DECIMAL(18,4) NOT NULL,
    balanceAfter DECIMAL(18,4) NOT NULL,
    referenceType NVARCHAR(50) NULL, -- proposition, prediction, penalty, etc.
    referenceId BIGINT NULL,
    correlationId UNIQUEIDENTIFIER NULL DEFAULT NEWID(), -- Agrupa transacciones del mismo evento
    description NVARCHAR(500) NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Transactions PRIMARY KEY (transactionId),
    CONSTRAINT FK_Transactions_Wallets FOREIGN KEY (walletId) REFERENCES Wallets(walletId),
    CONSTRAINT FK_Transactions_TransactionTypes FOREIGN KEY (transactionTypeId) REFERENCES TransactionTypes(transactionTypeId)
);

CREATE TABLE PaymentMethods (
    paymentMethodId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    countryId INT NULL,
    currencyId INT NULL,
    methodType NVARCHAR(50) NOT NULL, -- credit_card, bank_transfer, sinpe, paypal, etc.
    alias NVARCHAR(100) NULL,
    accountDetailsEncrypted VARBINARY(MAX) NULL, -- Cifrado con la Master Key
    isVerified BIT NOT NULL DEFAULT 0,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    deletedAt DATETIME2 NULL,
    CONSTRAINT PK_PaymentMethods PRIMARY KEY (paymentMethodId),
    CONSTRAINT FK_PaymentMethods_Players FOREIGN KEY (playerId) REFERENCES Players(playerId),
    CONSTRAINT FK_PaymentMethods_Countries FOREIGN KEY (countryId) REFERENCES Countries(countryId),
    CONSTRAINT FK_PaymentMethods_Currencies FOREIGN KEY (currencyId) REFERENCES Currencies(currencyId)
);

CREATE TABLE TransactionDetails (
    detailId BIGINT IDENTITY(1,1) NOT NULL,
    transactionId BIGINT NOT NULL,
    paymentMethodId BIGINT NULL,
    providerReference NVARCHAR(255) NULL,
    metadata NVARCHAR(MAX) NULL, -- Almacena JSON estructurado según el caso
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_TransactionDetails PRIMARY KEY (detailId),
    CONSTRAINT UQ_TransactionDetails_Transaction UNIQUE (transactionId),
    CONSTRAINT FK_TransactionDetails_Transactions FOREIGN KEY (transactionId) REFERENCES Transactions(transactionId),
    CONSTRAINT FK_TransactionDetails_PaymentMethods FOREIGN KEY (paymentMethodId) REFERENCES PaymentMethods(paymentMethodId)
);

CREATE TABLE PaymentAttempts (
    paymentAttemptId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    paymentMethodId BIGINT NULL,
    transactionId BIGINT NULL,
    attemptTypeId INT NOT NULL, -- Referencia a TransactionTypes (deposit, withdrawal, points_purchase)
    amount DECIMAL(18,4) NOT NULL,
    currencyId INT NOT NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, success, failed, cancelled
    providerReference NVARCHAR(255) NULL,
    errorMessage NVARCHAR(500) NULL,
    attemptedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    resolvedAt DATETIME2 NULL,
    CONSTRAINT PK_PaymentAttempts PRIMARY KEY (paymentAttemptId),
    CONSTRAINT FK_PaymentAttempts_Players FOREIGN KEY (playerId) REFERENCES Players(playerId),
    CONSTRAINT FK_PaymentAttempts_PaymentMethods FOREIGN KEY (paymentMethodId) REFERENCES PaymentMethods(paymentMethodId),
    CONSTRAINT FK_PaymentAttempts_Transactions FOREIGN KEY (transactionId) REFERENCES Transactions(transactionId),
    CONSTRAINT FK_PaymentAttempts_TransactionTypes FOREIGN KEY (attemptTypeId) REFERENCES TransactionTypes(transactionTypeId),
    CONSTRAINT FK_PaymentAttempts_Currencies FOREIGN KEY (currencyId) REFERENCES Currencies(currencyId)
);

-- ==============================================================================
-- 5. INTEGRACIÓN CON REDES SOCIALES (CACHE & TOKENS)
-- ==============================================================================

CREATE TABLE SocialAccounts (
    socialAccountId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    platformId INT NOT NULL,
    externalUserId NVARCHAR(255) NOT NULL, -- ID provisto por la API externa
    username NVARCHAR(100) NOT NULL,
    profileURL NVARCHAR(1000) NULL,
    linkedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    unlinkedAt DATETIME2 NULL,
    CONSTRAINT PK_SocialAccounts PRIMARY KEY (socialAccountId),
    CONSTRAINT UQ_SocialAccounts_Player_Platform UNIQUE (playerId, platformId),
    CONSTRAINT FK_SocialAccounts_Players FOREIGN KEY (playerId) REFERENCES Players(playerId),
    CONSTRAINT FK_SocialAccounts_SocialPlatforms FOREIGN KEY (platformId) REFERENCES SocialPlatforms(platformId)
);

CREATE TABLE SocialAccountTokens (
    tokenId BIGINT IDENTITY(1,1) NOT NULL,
    socialAccountId BIGINT NOT NULL,
    accessTokenEncrypted VARBINARY(MAX) NOT NULL, -- Cifrado con la Master Key
    refreshTokenEncrypted VARBINARY(MAX) NULL,
    scopes NVARCHAR(1000) NULL,
    issuedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    expiresAt DATETIME2 NULL,
    revokedAt DATETIME2 NULL,
    revokedReason NVARCHAR(100) NULL, -- refresh, user_unlink, etc.
    CONSTRAINT PK_SocialAccountTokens PRIMARY KEY (tokenId),
    CONSTRAINT FK_SocialAccountTokens_SocialAccounts FOREIGN KEY (socialAccountId) REFERENCES SocialAccounts(socialAccountId)
);

CREATE TABLE SocialContentCache (
    contentCacheId BIGINT IDENTITY(1,1) NOT NULL,
    socialAccountId BIGINT NOT NULL,
    externalContentId NVARCHAR(255) NOT NULL,
    contentType NVARCHAR(30) NOT NULL, -- post, story, reel, video, image
    contentURL NVARCHAR(1000) NULL,
    caption NVARCHAR(2000) NULL,
    rawMetadata NVARCHAR(MAX) NULL, -- JSON crudo de la red social
    publishedAt DATETIME2 NULL,
    fetchedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    expiresAt DATETIME2 NULL,
    CONSTRAINT PK_SocialContentCache PRIMARY KEY (contentCacheId),
    CONSTRAINT UQ_SocialContentCache_Account_External UNIQUE (socialAccountId, externalContentId),
    CONSTRAINT FK_SocialContentCache_SocialAccounts FOREIGN KEY (socialAccountId) REFERENCES SocialAccounts(socialAccountId)
);

-- ==============================================================================
-- 6. INTELIGENCIA ARTIFICIAL (JOBS & MODELS)
-- ==============================================================================

CREATE TABLE AIModels (
    modelId INT IDENTITY(1,1) NOT NULL,
    providerId INT NOT NULL,
    modelCode NVARCHAR(100) NOT NULL, -- Ej. claude-3-5-sonnet-20241022
    displayName NVARCHAR(200) NOT NULL,
    effectiveFrom DATETIME2 NOT NULL,
    effectiveTo DATETIME2 NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_AIModels PRIMARY KEY (modelId),
    CONSTRAINT FK_AIModels_AIProviders FOREIGN KEY (providerId) REFERENCES AIProviders(providerId)
);

CREATE TABLE AIAnalysisJobs (
    jobId BIGINT IDENTITY(1,1) NOT NULL,
    aiJobTypeId INT NOT NULL,
    modelId INT NOT NULL,
    referenceType NVARCHAR(50) NOT NULL, -- proposition, evidence, social_content
    referenceId BIGINT NOT NULL,
    aiJobStatusId INT NOT NULL,
    inputPayload NVARCHAR(MAX) NOT NULL, -- Contenedor JSON de la petición
    promptVersion NVARCHAR(50) NULL,
    startedAt DATETIME2 NULL,
    completedAt DATETIME2 NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_AIAnalysisJobs PRIMARY KEY (jobId),
    CONSTRAINT FK_AIAnalysisJobs_AIJobTypes FOREIGN KEY (aiJobTypeId) REFERENCES AIJobTypes(aiJobTypeId),
    CONSTRAINT FK_AIAnalysisJobs_AIModels FOREIGN KEY (modelId) REFERENCES AIModels(modelId),
    CONSTRAINT FK_AIAnalysisJobs_AIJobStatuses FOREIGN KEY (aiJobStatusId) REFERENCES AIJobStatuses(aiJobStatusId)
);

CREATE TABLE AIAnalysisResults (
    resultId BIGINT IDENTITY(1,1) NOT NULL,
    jobId BIGINT NOT NULL,
    outputPayload NVARCHAR(MAX) NOT NULL, -- JSON de respuesta completa de la AI
    decision NVARCHAR(50) NULL, -- approved, rejected, flagged, outcome_yes, etc.
    confidenceScore DECIMAL(5,4) NULL,
    flags NVARCHAR(500) NULL, -- JSON array de categorías de moderación
    errorMessage NVARCHAR(1000) NULL,
    tokensUsed INT NULL,
    latencyMs INT NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_AIAnalysisResults PRIMARY KEY (resultId),
    CONSTRAINT FK_AIAnalysisResults_AIAnalysisJobs FOREIGN KEY (jobId) REFERENCES AIAnalysisJobs(jobId)
);

-- ==============================================================================
-- 7. PROPOSICIONES, VOTACIONES Y PREDICCIONES
-- ==============================================================================

CREATE TABLE Propositions (
    propositionId BIGINT IDENTITY(1,1) NOT NULL,
    creatorId BIGINT NOT NULL,
    subjectPlayerId BIGINT NULL,
    propositionText NVARCHAR(1000) NOT NULL,
    propositionStatusId INT NOT NULL,
    aiJobId BIGINT NULL,
    winningVoteId BIGINT NULL, -- Se agregará FK vía ALTER TABLE por relación circular
    acceptedAt DATETIME2 NULL,
    predictionsCloseAt DATETIME2 NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Propositions PRIMARY KEY (propositionId),
    CONSTRAINT FK_Propositions_Players_Creator FOREIGN KEY (creatorId) REFERENCES Players(playerId),
    CONSTRAINT FK_Propositions_Players_Subject FOREIGN KEY (subjectPlayerId) REFERENCES Players(playerId),
    CONSTRAINT FK_Propositions_PropositionStatuses FOREIGN KEY (propositionStatusId) REFERENCES PropositionStatuses(propositionStatusId),
    CONSTRAINT FK_Propositions_AIAnalysisJobs FOREIGN KEY (aiJobId) REFERENCES AIAnalysisJobs(jobId)
);

CREATE TABLE PropositionVotes (
    voteId BIGINT IDENTITY(1,1) NOT NULL,
    propositionId BIGINT NOT NULL,
    voterId BIGINT NOT NULL,
    voteValue NVARCHAR(10) NOT NULL, -- yes / no
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PropositionVotes PRIMARY KEY (voteId),
    CONSTRAINT UQ_PropositionVotes_Prop_Voter UNIQUE (propositionId, voterId),
    CONSTRAINT FK_PropositionVotes_Propositions FOREIGN KEY (propositionId) REFERENCES Propositions(propositionId),
    CONSTRAINT FK_PropositionVotes_Players FOREIGN KEY (voterId) REFERENCES Players(playerId)
);

-- Aplicamos la Llave Foránea circular rezagada de Propositions
ALTER TABLE Propositions 
    ADD CONSTRAINT FK_Propositions_PropositionVotes 
    FOREIGN KEY (winningVoteId) REFERENCES PropositionVotes(voteId);

CREATE TABLE PropositionEvents (
    eventId BIGINT IDENTITY(1,1) NOT NULL,
    propositionId BIGINT NOT NULL,
    fromStatusId INT NULL,
    toStatusId INT NOT NULL,
    triggeredBy BIGINT NULL, -- NULL si es automatizado por el sistema
    notes NVARCHAR(500) NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PropositionEvents PRIMARY KEY (eventId),
    CONSTRAINT FK_PropositionEvents_Propositions FOREIGN KEY (propositionId) REFERENCES Propositions(propositionId),
    CONSTRAINT FK_PropositionEvents_PropositionStatuses_From FOREIGN KEY (fromStatusId) REFERENCES PropositionStatuses(propositionStatusId),
    CONSTRAINT FK_PropositionEvents_PropositionStatuses_To FOREIGN KEY (toStatusId) REFERENCES PropositionStatuses(propositionStatusId),
    CONSTRAINT FK_PropositionEvents_Players FOREIGN KEY (triggeredBy) REFERENCES Players(playerId)
);

CREATE TABLE PropositionOutcomeRecords (
    outcomeRecordId BIGINT IDENTITY(1,1) NOT NULL,
    propositionId BIGINT NOT NULL,
    outcomeId INT NOT NULL,
    validationJobId BIGINT NULL,
    validatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    validatedBy BIGINT NULL, -- NULL si es validación automática AI
    CONSTRAINT PK_PropositionOutcomeRecords PRIMARY KEY (outcomeRecordId),
    CONSTRAINT UQ_PropositionOutcomeRecords_Prop UNIQUE (propositionId),
    CONSTRAINT FK_PropositionOutcomeRecords_Propositions FOREIGN KEY (propositionId) REFERENCES Propositions(propositionId),
    CONSTRAINT FK_PropositionOutcomeRecords_PropositionOutcomes FOREIGN KEY (outcomeId) REFERENCES PropositionOutcomes(outcomeId),
    CONSTRAINT FK_PropositionOutcomeRecords_AIAnalysisJobs FOREIGN KEY (validationJobId) REFERENCES AIAnalysisJobs(jobId),
    CONSTRAINT FK_PropositionOutcomeRecords_Players FOREIGN KEY (validatedBy) REFERENCES Players(playerId)
);

CREATE TABLE Predictions (
    predictionId BIGINT IDENTITY(1,1) NOT NULL,
    propositionId BIGINT NOT NULL,
    predictorId BIGINT NOT NULL,
    predictionOptionId INT NOT NULL,
    walletId BIGINT NOT NULL, -- Define el tipo de moneda del Wager (PTS o Dinero Real)
    amountWagered DECIMAL(18,4) NOT NULL,
    lockedAt DATETIME2 NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Predictions PRIMARY KEY (predictionId),
    CONSTRAINT UQ_Predictions_Prop_Predictor_Wallet UNIQUE (propositionId, predictorId, walletId),
    CONSTRAINT FK_Predictions_Propositions FOREIGN KEY (propositionId) REFERENCES Propositions(propositionId),
    CONSTRAINT FK_Predictions_Players FOREIGN KEY (predictorId) REFERENCES Players(playerId),
    CONSTRAINT FK_Predictions_PredictionOptions FOREIGN KEY (predictionOptionId) REFERENCES PredictionOptions(predictionOptionId),
    CONSTRAINT FK_Predictions_Wallets FOREIGN KEY (walletId) REFERENCES Wallets(walletId)
);

CREATE TABLE PredictionWagerHistory (
    wagerId BIGINT IDENTITY(1,1) NOT NULL,
    predictionId BIGINT NOT NULL,
    additionalAmount DECIMAL(18,4) NOT NULL,
    totalAfter DECIMAL(18,4) NOT NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PredictionWagerHistory PRIMARY KEY (wagerId),
    CONSTRAINT FK_PredictionWagerHistory_Predictions FOREIGN KEY (predictionId) REFERENCES Predictions(predictionId)
);

CREATE TABLE PredictionResults (
    resultId BIGINT IDENTITY(1,1) NOT NULL,
    predictionId BIGINT NOT NULL,
    isWinner BIT NOT NULL,
    amountEarned DECIMAL(18,4) NOT NULL DEFAULT 0,
    transactionId BIGINT NULL, -- Transacción vinculada al pago de la recompensa
    resolvedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PredictionResults PRIMARY KEY (resultId),
    CONSTRAINT UQ_PredictionResults_Prediction UNIQUE (predictionId),
    CONSTRAINT FK_PredictionResults_Predictions FOREIGN KEY (predictionId) REFERENCES Predictions(predictionId),
    CONSTRAINT FK_PredictionResults_Transactions FOREIGN KEY (transactionId) REFERENCES Transactions(transactionId)
);

-- ==============================================================================
-- 8. EVIDENCIAS, DISTRIBUCIONES Y PENALIZACIONES
-- ==============================================================================

CREATE TABLE EvidenceSubmissions (
    evidenceId BIGINT IDENTITY(1,1) NOT NULL,
    propositionId BIGINT NOT NULL,
    submittedBy BIGINT NOT NULL,
    socialAccountId BIGINT NULL,
    fileId BIGINT NULL,
    socialContentCacheId BIGINT NULL,
    hasGathelHashtag BIT NOT NULL DEFAULT 0,
    aiJobId BIGINT NULL,
    manualReviewRequired BIT NOT NULL DEFAULT 0,
    submittedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_EvidenceSubmissions PRIMARY KEY (evidenceId),
    CONSTRAINT FK_EvidenceSubmissions_Propositions FOREIGN KEY (propositionId) REFERENCES Propositions(propositionId),
    CONSTRAINT FK_EvidenceSubmissions_Players FOREIGN KEY (submittedBy) REFERENCES Players(playerId),
    CONSTRAINT FK_EvidenceSubmissions_SocialAccounts FOREIGN KEY (socialAccountId) REFERENCES SocialAccounts(socialAccountId),
    CONSTRAINT FK_EvidenceSubmissions_Files FOREIGN KEY (fileId) REFERENCES Files(fileId),
    CONSTRAINT FK_EvidenceSubmissions_SocialContentCache FOREIGN KEY (socialContentCacheId) REFERENCES SocialContentCache(contentCacheId),
    CONSTRAINT FK_EvidenceSubmissions_AIAnalysisJobs FOREIGN KEY (aiJobId) REFERENCES AIAnalysisJobs(jobId)
);

CREATE TABLE RewardDistributions (
    distributionId BIGINT IDENTITY(1,1) NOT NULL,
    propositionId BIGINT NOT NULL,
    transactionId BIGINT NOT NULL,
    distributionTypeId INT NOT NULL, -- winner_reward, commission_platform, commission_proposer
    percentageShare DECIMAL(5,2) NULL,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_RewardDistributions PRIMARY KEY (distributionId),
    CONSTRAINT FK_RewardDistributions_Propositions FOREIGN KEY (propositionId) REFERENCES Propositions(propositionId),
    CONSTRAINT FK_RewardDistributions_Transactions FOREIGN KEY (transactionId) REFERENCES Transactions(transactionId),
    CONSTRAINT FK_RewardDistributions_TransactionTypes FOREIGN KEY (distributionTypeId) REFERENCES TransactionTypes(transactionTypeId)
);

CREATE TABLE PenaltyTransactions (
    penaltyTxId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    penaltyCatalogId INT NOT NULL,
    propositionId BIGINT NULL,
    transactionId BIGINT NOT NULL, -- Transacción de débito real
    pointsDeducted BIGINT NOT NULL,
    notes NVARCHAR(500) NULL,
    appliedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PenaltyTransactions PRIMARY KEY (penaltyTxId),
    CONSTRAINT FK_PenaltyTransactions_Players FOREIGN KEY (playerId) REFERENCES Players(playerId),
    CONSTRAINT FK_PenaltyTransactions_PenaltyCatalog FOREIGN KEY (penaltyCatalogId) REFERENCES PenaltyCatalog(penaltyCatalogId),
    CONSTRAINT FK_PenaltyTransactions_Propositions FOREIGN KEY (propositionId) REFERENCES Propositions(propositionId),
    CONSTRAINT FK_PenaltyTransactions_Transactions FOREIGN KEY (transactionId) REFERENCES Transactions(transactionId)
);

-- ==============================================================================
-- 9. SOCIOS AFILIADOS Y REDENCIONES DE PUNTOS
-- ==============================================================================

CREATE TABLE AffiliatePartners (
    partnerId INT IDENTITY(1,1) NOT NULL,
    partnerName NVARCHAR(100) NOT NULL,
    countryId INT NULL,
    logoFileId BIGINT NULL,
    websiteURL NVARCHAR(1000) NULL,
    isActive BIT NOT NULL DEFAULT 1,
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    createdBy BIGINT NOT NULL, -- Administrador asignado
    updatedAt DATETIME2 NULL,
    updatedBy BIGINT NULL,
    deletedAt DATETIME2 NULL,
    deletedBy BIGINT NULL,
    CONSTRAINT PK_AffiliatePartners PRIMARY KEY (partnerId),
    CONSTRAINT FK_AffiliatePartners_Countries FOREIGN KEY (countryId) REFERENCES Countries(countryId),
    CONSTRAINT FK_AffiliatePartners_Files FOREIGN KEY (logoFileId) REFERENCES Files(fileId),
    CONSTRAINT FK_AffiliatePartners_Players_Created FOREIGN KEY (createdBy) REFERENCES Players(playerId),
    CONSTRAINT FK_AffiliatePartners_Players_Updated FOREIGN KEY (updatedBy) REFERENCES Players(playerId),
    CONSTRAINT FK_AffiliatePartners_Players_Deleted FOREIGN KEY (deletedBy) REFERENCES Players(playerId)
);

CREATE TABLE PointsRedemptions (
    redemptionId BIGINT IDENTITY(1,1) NOT NULL,
    playerId BIGINT NOT NULL,
    partnerId INT NOT NULL,
    transactionId BIGINT NOT NULL, -- Transacción asociada al cobro/canje de PTS
    pointsSpent BIGINT NOT NULL,
    rewardDetail NVARCHAR(500) NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, completed, rejected, expired
    createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PointsRedemptions PRIMARY KEY (redemptionId),
    CONSTRAINT FK_PointsRedemptions_Players FOREIGN KEY (playerId) REFERENCES Players(playerId),
    CONSTRAINT FK_PointsRedemptions_AffiliatePartners FOREIGN KEY (partnerId) REFERENCES AffiliatePartners(partnerId),
    CONSTRAINT FK_PointsRedemptions_Transactions FOREIGN KEY (transactionId) REFERENCES Transactions(transactionId)
);

-- ==============================================================================
-- 10. TRAZABILIDAD Y AUDITORÍA SOBERANA
-- ==============================================================================

CREATE TABLE AuditLog (
    auditId BIGINT IDENTITY(1,1) NOT NULL,
    entityName NVARCHAR(100) NOT NULL, -- Nombre de la tabla
    entityId NVARCHAR(50) NOT NULL,   -- Clave primaria del registro modificado
    operation CHAR(6) NOT NULL,       -- INSERT, UPDATE, DELETE
    performedBy BIGINT NULL,          -- NULL si es un trigger interno del sistema
    sessionId BIGINT NULL,
    correlationId UNIQUEIDENTIFIER NULL,
    ipAddress NVARCHAR(45) NULL,
    oldSnapshot NVARCHAR(MAX) NULL,   -- Captura estructurada JSON del estado anterior
    newSnapshot NVARCHAR(MAX) NULL,   -- Captura estructurada JSON del estado posterior
    occurredAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_AuditLog PRIMARY KEY (auditId),
    CONSTRAINT FK_AuditLog_Players FOREIGN KEY (performedBy) REFERENCES Players(playerId),
    CONSTRAINT FK_AuditLog_PlayerSessions FOREIGN KEY (sessionId) REFERENCES PlayerSessions(sessionId)
);
GO