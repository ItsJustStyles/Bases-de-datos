-- ==============================================================================
-- V2__stored_procedures_gathel.sql
-- Gathel Gaming Platform — Stored Procedures Transaccionales del MVP
-- Versionado con Flyway | SQL Server 2022
-- ==============================================================================

-- ==============================================================================
-- SP 1: usp_RegisterPlayer
-- Registra un nuevo jugador, crea sus wallets (PTS + USD) y otorga puntos iniciales.
-- ==============================================================================
GO
CREATE OR ALTER PROCEDURE dbo.usp_RegisterPlayer
    @username       NVARCHAR(50),
    @email          NVARCHAR(255),
    @passwordHash   VARBINARY(64),
    @passwordSalt   VARBINARY(32),
    @countryId      INT = NULL,
    @newPlayerId    BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @activeStatusId     INT;
    DECLARE @ptsCurrencyId      INT;
    DECLARE @usdCurrencyId      INT;
    DECLARE @depositTypeId      INT;
    DECLARE @welcomePoints      BIGINT;
    DECLARE @ptsWalletId        BIGINT;
    DECLARE @correlationId      UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar unicidad antes de insertar
        IF EXISTS (SELECT 1 FROM dbo.Players WHERE username = @username)
            THROW 50001, 'El username ya está en uso.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Players WHERE email = @email)
            THROW 50002, 'El email ya está registrado.', 1;

        -- Obtener IDs de catálogos
        SELECT @activeStatusId = playerStatusId FROM dbo.PlayerStatuses WHERE code = 'active';
        SELECT @ptsCurrencyId  = currencyId     FROM dbo.Currencies       WHERE code = 'PTS';
        SELECT @usdCurrencyId  = currencyId     FROM dbo.Currencies       WHERE code = 'USD';
        SELECT @depositTypeId  = transactionTypeId FROM dbo.TransactionTypes WHERE code = 'deposit';

        -- Leer puntos de bienvenida de la configuración vigente
        SELECT TOP 1 @welcomePoints = welcomePoints
        FROM dbo.PlatformConfig
        WHERE effectiveFrom <= GETUTCDATE()
          AND (effectiveTo IS NULL OR effectiveTo > GETUTCDATE())
        ORDER BY effectiveFrom DESC;

        SET @welcomePoints = ISNULL(@welcomePoints, 100);

        -- Insertar jugador
        INSERT INTO dbo.Players (username, email, passwordHash, passwordSalt, playerStatusId, countryId, isVerified, createdAt)
        VALUES (@username, @email, @passwordHash, @passwordSalt, @activeStatusId, @countryId, 0, GETUTCDATE());

        SET @newPlayerId = SCOPE_IDENTITY();

        -- Crear wallet de PTS
        INSERT INTO dbo.Wallets (playerId, currencyId, balance, reservedBalance, createdAt)
        VALUES (@newPlayerId, @ptsCurrencyId, @welcomePoints, 0, GETUTCDATE());

        SET @ptsWalletId = SCOPE_IDENTITY();

        -- Crear wallet de USD
        INSERT INTO dbo.Wallets (playerId, currencyId, balance, reservedBalance, createdAt)
        VALUES (@newPlayerId, @usdCurrencyId, 0, 0, GETUTCDATE());

        -- Registrar transacción de puntos de bienvenida
        INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                      referenceType, referenceId, correlationId, description, createdAt)
        VALUES (@ptsWalletId, @depositTypeId, @welcomePoints, 0, @welcomePoints,
                'player', @newPlayerId, @correlationId, 'Puntos de bienvenida', GETUTCDATE());

        -- Log de auditoría
        INSERT INTO dbo.AuditLog (entityName, entityId, operation, performedBy, correlationId, newSnapshot, occurredAt)
        VALUES ('Players', CAST(@newPlayerId AS NVARCHAR(50)), 'INSERT', NULL, @correlationId,
                (SELECT @username AS username, @email AS email FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 2: usp_CreateProposition
-- Crea una proposición, valida saldo mínimo del sujeto, registra evento inicial.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_CreateProposition
    @creatorId          BIGINT,
    @subjectPlayerId    BIGINT = NULL,
    @propositionText    NVARCHAR(1000),
    @newPropositionId   BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @pendingAiStatusId  INT;
    DECLARE @ptsCurrencyId      INT;
    DECLARE @minPoints          BIGINT;
    DECLARE @subjectBalance     DECIMAL(18,4);
    DECLARE @subjectWalletId    BIGINT;
    DECLARE @correlationId      UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el creador existe y está activo
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Players p
            JOIN dbo.PlayerStatuses ps ON p.playerStatusId = ps.playerStatusId
            WHERE p.playerId = @creatorId AND ps.code = 'active'
        )
            THROW 50010, 'El creador no existe o no está activo.', 1;

        -- Obtener IDs
        SELECT @pendingAiStatusId = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_ai';
        SELECT @ptsCurrencyId     = currencyId          FROM dbo.Currencies           WHERE code = 'PTS';

        -- Configuración vigente de puntos mínimos para crear proposición
        SELECT TOP 1 @minPoints = minPointsReserveForProposition
        FROM dbo.PlatformConfig
        WHERE effectiveFrom <= GETUTCDATE()
          AND (effectiveTo IS NULL OR effectiveTo > GETUTCDATE())
        ORDER BY effectiveFrom DESC;

        SET @minPoints = ISNULL(@minPoints, 15); -- default si no hay config

        -- Si hay sujeto, verificar que tenga suficientes puntos para cubrir penalización
        IF @subjectPlayerId IS NOT NULL
        BEGIN
            SELECT @subjectWalletId = walletId, @subjectBalance = balance
            FROM dbo.Wallets
            WHERE playerId = @subjectPlayerId AND currencyId = @ptsCurrencyId;

            IF @subjectBalance < @minPoints
                THROW 50011, 'El sujeto no tiene suficientes puntos para cubrir una posible penalización.', 1;
        END

        -- Insertar proposición en estado pending_ai
        INSERT INTO dbo.Propositions (creatorId, subjectPlayerId, propositionText, propositionStatusId,
                                      aiJobId, winningVoteId, acceptedAt, predictionsCloseAt, createdAt)
        VALUES (@creatorId, @subjectPlayerId, @propositionText, @pendingAiStatusId,
                NULL, NULL, NULL, NULL, GETUTCDATE());

        SET @newPropositionId = SCOPE_IDENTITY();

        -- Registrar evento de creación
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@newPropositionId, NULL, @pendingAiStatusId, @creatorId, 'Proposición creada, enviada a moderación AI', GETUTCDATE());

        -- Auditoría
        INSERT INTO dbo.AuditLog (entityName, entityId, operation, performedBy, correlationId, newSnapshot, occurredAt)
        VALUES ('Propositions', CAST(@newPropositionId AS NVARCHAR(50)), 'INSERT', @creatorId, @correlationId,
                (SELECT @newPropositionId AS propositionId, @creatorId AS creatorId, @propositionText AS text FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 3: usp_ActivateProposition
-- El sujeto acepta la proposición ganadora; fija fecha de cierre de predicciones.
-- Transición: pending_acceptance → active
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ActivateProposition
    @propositionId      BIGINT,
    @subjectPlayerId    BIGINT,
    @predictionsCloseAt DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @currentStatusId    INT;
    DECLARE @pendingAcceptId    INT;
    DECLARE @activeStatusId     INT;
    DECLARE @correlationId      UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @pendingAcceptId = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_acceptance';
        SELECT @activeStatusId  = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'active';

        -- Leer estado actual con bloqueo
        SELECT @currentStatusId = propositionStatusId
        FROM dbo.Propositions WITH (UPDLOCK, ROWLOCK)
        WHERE propositionId = @propositionId;

        IF @currentStatusId IS NULL
            THROW 50020, 'La proposición no existe.', 1;

        IF @currentStatusId <> @pendingAcceptId
            THROW 50021, 'La proposición no está en estado pending_acceptance.', 1;

        -- Verificar que quien acepta es el sujeto
        IF NOT EXISTS (SELECT 1 FROM dbo.Propositions WHERE propositionId = @propositionId AND subjectPlayerId = @subjectPlayerId)
            THROW 50022, 'Solo el jugador sujeto puede aceptar esta proposición.', 1;

        IF @predictionsCloseAt <= GETUTCDATE()
            THROW 50023, 'La fecha de cierre de predicciones debe ser futura.', 1;

        -- Activar
        UPDATE dbo.Propositions
        SET propositionStatusId = @activeStatusId,
            acceptedAt          = GETUTCDATE(),
            predictionsCloseAt  = @predictionsCloseAt
        WHERE propositionId = @propositionId;

        -- Evento de transición
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@propositionId, @pendingAcceptId, @activeStatusId, @subjectPlayerId,
                'Proposición aceptada por el sujeto. Predicciones habilitadas.', GETUTCDATE());

        -- Auditoría
        INSERT INTO dbo.AuditLog (entityName, entityId, operation, performedBy, correlationId, newSnapshot, occurredAt)
        VALUES ('Propositions', CAST(@propositionId AS NVARCHAR(50)), 'UPDATE', @subjectPlayerId, @correlationId,
                (SELECT @propositionId AS propositionId, 'active' AS newStatus, @predictionsCloseAt AS predictionsCloseAt FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 4: usp_RejectProposition
-- El sujeto rechaza la proposición ganadora; pierde 1 PTS.
-- Transición: pending_acceptance → rejected_subject
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_RejectProposition
    @propositionId   BIGINT,
    @subjectPlayerId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @pendingAcceptId    INT;
    DECLARE @rejectedSubjId     INT;
    DECLARE @ptsCurrencyId      INT;
    DECLARE @wagerTypeId        INT;
    DECLARE @subjectWalletId    BIGINT;
    DECLARE @currentBalance     DECIMAL(18,4);
    DECLARE @penaltyTxId        BIGINT;
    DECLARE @penCatalogId       INT;
    DECLARE @correlationId      UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @pendingAcceptId = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_acceptance';
        SELECT @rejectedSubjId  = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'rejected_subject';
        SELECT @ptsCurrencyId   = currencyId          FROM dbo.Currencies           WHERE code = 'PTS';
        SELECT @wagerTypeId     = transactionTypeId   FROM dbo.TransactionTypes     WHERE code = 'wager';
        SELECT @penCatalogId    = penaltyCatalogId     FROM dbo.PenaltyCatalog       WHERE code = 'proposition_rejection'
                                                                                       AND (effectiveTo IS NULL OR effectiveTo > GETUTCDATE());

        -- Verificar estado y sujeto con bloqueo
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Propositions WITH (UPDLOCK, ROWLOCK)
            WHERE propositionId = @propositionId
              AND propositionStatusId = @pendingAcceptId
              AND subjectPlayerId = @subjectPlayerId
        )
            THROW 50030, 'La proposición no está en pending_acceptance o el sujeto no coincide.', 1;

        -- Obtener wallet PTS del sujeto
        SELECT @subjectWalletId = walletId, @currentBalance = balance
        FROM dbo.Wallets
        WHERE playerId = @subjectPlayerId AND currencyId = @ptsCurrencyId;

        IF @currentBalance < 1
            THROW 50031, 'El sujeto no tiene suficientes puntos para la penalización por rechazo.', 1;

        -- Descontar 1 PTS
        UPDATE dbo.Wallets
        SET balance = balance - 1, updatedAt = GETUTCDATE()
        WHERE walletId = @subjectWalletId;

        -- Transacción de penalización
        INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                      referenceType, referenceId, correlationId, description, createdAt)
        VALUES (@subjectWalletId, @wagerTypeId, -1, @currentBalance, @currentBalance - 1,
                'proposition', @propositionId, @correlationId, 'Penalización por rechazo de proposición', GETUTCDATE());

        DECLARE @txId BIGINT = SCOPE_IDENTITY();

        -- Registro de PenaltyTransaction
        INSERT INTO dbo.PenaltyTransactions (playerId, penaltyCatalogId, propositionId, transactionId,
                                              pointsDeducted, notes, appliedAt)
        VALUES (@subjectPlayerId, @penCatalogId, @propositionId, @txId, 1,
                'Jugador rechazó la proposición ganadora', GETUTCDATE());

        -- Cambiar estado de proposición
        UPDATE dbo.Propositions
        SET propositionStatusId = @rejectedSubjId
        WHERE propositionId = @propositionId;

        -- Evento de transición
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@propositionId, @pendingAcceptId, @rejectedSubjId, @subjectPlayerId,
                'Proposición rechazada por el sujeto. -1 PTS aplicado.', GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 5: usp_PlacePrediction
-- Un jugador realiza una predicción (PTS o dinero real) sobre una proposición activa.
-- Reserva el monto en el wallet. Máximo 1 PTS por predicción en puntos.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_PlacePrediction
    @propositionId      BIGINT,
    @predictorId        BIGINT,
    @predictionOption   NVARCHAR(10),  -- 'yes' o 'no'
    @walletId           BIGINT,        -- wallet que se debita (PTS o dinero)
    @amountWagered      DECIMAL(18,4),
    @newPredictionId    BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @activeStatusId     INT;
    DECLARE @predOptionId       INT;
    DECLARE @ptsCurrencyId      INT;
    DECLARE @wagerTypeId        INT;
    DECLARE @walletCurrencyId   INT;
    DECLARE @currentBalance     DECIMAL(18,4);
    DECLARE @propCloseAt        DATETIME2;
    DECLARE @correlationId      UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @activeStatusId = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'active';
        SELECT @predOptionId   = predictionOptionId  FROM dbo.PredictionOptions    WHERE code = @predictionOption;
        SELECT @ptsCurrencyId  = currencyId          FROM dbo.Currencies           WHERE code = 'PTS';
        SELECT @wagerTypeId    = transactionTypeId   FROM dbo.TransactionTypes     WHERE code = 'wager';

        IF @predOptionId IS NULL
            THROW 50040, 'Opción de predicción inválida. Use yes o no.', 1;

        -- Verificar proposición activa y vigente
        SELECT @propCloseAt = predictionsCloseAt
        FROM dbo.Propositions WITH (ROWLOCK)
        WHERE propositionId = @propositionId AND propositionStatusId = @activeStatusId;

        IF @propCloseAt IS NULL
            THROW 50041, 'La proposición no está activa.', 1;

        IF GETUTCDATE() > @propCloseAt
            THROW 50042, 'El período de predicciones ya cerró.', 1;

        -- Verificar que el predictor no haya predicho ya sobre esta proposición con esta wallet
        IF EXISTS (SELECT 1 FROM dbo.Predictions WHERE propositionId = @propositionId AND predictorId = @predictorId AND walletId = @walletId)
            THROW 50043, 'Ya existe una predicción de este jugador para esta proposición con este wallet.', 1;

        -- Verificar que el wallet pertenece al predictor
        SELECT @walletCurrencyId = currencyId, @currentBalance = balance
        FROM dbo.Wallets WITH (UPDLOCK, ROWLOCK)
        WHERE walletId = @walletId AND playerId = @predictorId;

        IF @walletCurrencyId IS NULL
            THROW 50044, 'El wallet no pertenece al predictor.', 1;

        -- Si es PTS, máximo 1 punto
        IF @walletCurrencyId = @ptsCurrencyId AND @amountWagered > 1
            THROW 50045, 'Las predicciones con PTS tienen un máximo de 1 punto.', 1;

        IF @amountWagered <= 0
            THROW 50046, 'El monto apostado debe ser mayor a cero.', 1;

        IF @currentBalance < @amountWagered
            THROW 50047, 'Saldo insuficiente en el wallet.', 1;

        -- Reservar monto en el wallet (no se descuenta aún, se reserva)
        UPDATE dbo.Wallets
        SET balance         = balance - @amountWagered,
            reservedBalance = reservedBalance + @amountWagered,
            updatedAt       = GETUTCDATE()
        WHERE walletId = @walletId;

        -- Registrar predicción
        INSERT INTO dbo.Predictions (propositionId, predictorId, predictionOptionId, walletId, amountWagered, lockedAt, createdAt)
        VALUES (@propositionId, @predictorId, @predOptionId, @walletId, @amountWagered, NULL, GETUTCDATE());

        SET @newPredictionId = SCOPE_IDENTITY();

        -- Registrar en historial de apuestas
        INSERT INTO dbo.PredictionWagerHistory (predictionId, additionalAmount, totalAfter, createdAt)
        VALUES (@newPredictionId, @amountWagered, @amountWagered, GETUTCDATE());

        -- Transacción de reserva
        INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                      referenceType, referenceId, correlationId, description, createdAt)
        VALUES (@walletId, @wagerTypeId, -@amountWagered, @currentBalance, @currentBalance - @amountWagered,
                'prediction', @newPredictionId, @correlationId, 'Reserva de apuesta en predicción', GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 6: usp_IncreasePredictionWager
-- Aumenta el monto apostado en una predicción antes del cierre.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_IncreasePredictionWager
    @predictionId       BIGINT,
    @predictorId        BIGINT,
    @additionalAmount   DECIMAL(18,4)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @propCloseAt        DATETIME2;
    DECLARE @walletId           BIGINT;
    DECLARE @walletCurrencyId   INT;
    DECLARE @ptsCurrencyId      INT;
    DECLARE @currentBalance     DECIMAL(18,4);
    DECLARE @currentWagered     DECIMAL(18,4);
    DECLARE @wagerTypeId        INT;
    DECLARE @correlationId      UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @ptsCurrencyId = currencyId        FROM dbo.Currencies       WHERE code = 'PTS';
        SELECT @wagerTypeId   = transactionTypeId FROM dbo.TransactionTypes WHERE code = 'wager';

        -- Verificar que la predicción pertenece al predictor y obtener datos
        SELECT @walletId = p.walletId, @currentWagered = p.amountWagered,
               @propCloseAt = pr.predictionsCloseAt
        FROM dbo.Predictions p
        JOIN dbo.Propositions pr ON p.propositionId = pr.propositionId
        WHERE p.predictionId = @predictionId AND p.predictorId = @predictorId AND p.lockedAt IS NULL;

        IF @walletId IS NULL
            THROW 50050, 'La predicción no existe, no pertenece al jugador, o ya está bloqueada.', 1;

        IF GETUTCDATE() > @propCloseAt
            THROW 50051, 'El período de predicciones ya cerró. No se puede aumentar la apuesta.', 1;

        SELECT @walletCurrencyId = currencyId, @currentBalance = balance
        FROM dbo.Wallets WITH (UPDLOCK, ROWLOCK)
        WHERE walletId = @walletId;

        -- Si es PTS, el total no puede superar 1
        IF @walletCurrencyId = @ptsCurrencyId AND (@currentWagered + @additionalAmount) > 1
            THROW 50052, 'Las predicciones con PTS tienen un máximo de 1 punto total.', 1;

        IF @currentBalance < @additionalAmount
            THROW 50053, 'Saldo insuficiente para aumentar la apuesta.', 1;

        -- Actualizar wallet y predicción
        UPDATE dbo.Wallets
        SET balance = balance - @additionalAmount, reservedBalance = reservedBalance + @additionalAmount, updatedAt = GETUTCDATE()
        WHERE walletId = @walletId;

        UPDATE dbo.Predictions
        SET amountWagered = amountWagered + @additionalAmount
        WHERE predictionId = @predictionId;

        -- Historial
        INSERT INTO dbo.PredictionWagerHistory (predictionId, additionalAmount, totalAfter, createdAt)
        VALUES (@predictionId, @additionalAmount, @currentWagered + @additionalAmount, GETUTCDATE());

        -- Transacción
        INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                      referenceType, referenceId, correlationId, description, createdAt)
        VALUES (@walletId, @wagerTypeId, -@additionalAmount, @currentBalance, @currentBalance - @additionalAmount,
                'prediction', @predictionId, @correlationId, 'Aumento de apuesta en predicción', GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 7: usp_ClosePropositionPredictions
-- Cierra las predicciones de una proposición (bloqueo). Transición: active → closed
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ClosePropositionPredictions
    @propositionId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @activeStatusId  INT;
    DECLARE @closedStatusId  INT;
    DECLARE @currentStatusId INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @activeStatusId  = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'active';
        SELECT @closedStatusId  = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'closed';

        SELECT @currentStatusId = propositionStatusId
        FROM dbo.Propositions WITH (UPDLOCK, ROWLOCK)
        WHERE propositionId = @propositionId;

        IF @currentStatusId <> @activeStatusId
            THROW 50060, 'La proposición no está activa; no se puede cerrar.', 1;

        -- Bloquear predicciones
        UPDATE dbo.Predictions
        SET lockedAt = GETUTCDATE()
        WHERE propositionId = @propositionId AND lockedAt IS NULL;

        -- Cambiar estado
        UPDATE dbo.Propositions
        SET propositionStatusId = @closedStatusId
        WHERE propositionId = @propositionId;

        -- Evento de cierre
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@propositionId, @activeStatusId, @closedStatusId, NULL,
                'Cierre automático de predicciones al vencer el período.', GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 8: usp_ValidateAndDistributeRewards
-- Valida el outcome de una proposición cerrada y distribuye recompensas.
-- Transición: closed → validated
-- Aplica comisiones de plataforma y del creador antes de distribuir.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ValidateAndDistributeRewards
    @propositionId  BIGINT,
    @outcomeCode    NVARCHAR(20),   -- 'yes', 'no', 'cancelled', 'unresolvable'
    @validatedBy    BIGINT = NULL   -- NULL = validación automática AI
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @closedStatusId         INT;
    DECLARE @validatedStatusId      INT;
    DECLARE @outcomeId              INT;
    DECLARE @ptsCurrencyId          INT;
    DECLARE @rewardTypeId           INT;
    DECLARE @commPlataformTypeId    INT;
    DECLARE @commProposerTypeId     INT;
    DECLARE @refundTypeId           INT;
    DECLARE @penaltyPct             DECIMAL(5,2);
    DECLARE @platformPtsPct         DECIMAL(5,2);
    DECLARE @proposerPtsPct         DECIMAL(5,2);
    DECLARE @creatorId              BIGINT;
    DECLARE @subjectPlayerId        BIGINT;
    DECLARE @correlationId          UNIQUEIDENTIFIER = NEWID();

    -- Totales del pozo por moneda
    DECLARE @totalPotPTS            DECIMAL(18,4) = 0;
    DECLARE @totalPotMoney          DECIMAL(18,4) = 0;

    -- Para distribución proporcional
    DECLARE @winnerTotalPTS         DECIMAL(18,4) = 0;
    DECLARE @winnerTotalMoney       DECIMAL(18,4) = 0;
    DECLARE @winningOptionId        INT;
    DECLARE @losingOptionId         INT;

    -- Cursores temporales
    DECLARE @predictionId           BIGINT;
    DECLARE @predictorWalletId      BIGINT;
    DECLARE @predictorPlayerId      BIGINT;
    DECLARE @predOptId              INT;
    DECLARE @wagered                DECIMAL(18,4);
    DECLARE @walletCurrId           INT;
    DECLARE @earnedAmount           DECIMAL(18,4);
    DECLARE @rewardTxId             BIGINT;
    DECLARE @balBefore              DECIMAL(18,4);
    DECLARE @commPlatformPTS        DECIMAL(18,4);
    DECLARE @commProposerPTS        DECIMAL(18,4);
    DECLARE @creatorWalletPTS       BIGINT;
    DECLARE @creatorBalBefore       DECIMAL(18,4);
    DECLARE @platformWalletPTS      BIGINT;  -- se maneja como transacción sin wallet real

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @closedStatusId    = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'closed';
        SELECT @validatedStatusId = propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'validated';
        SELECT @ptsCurrencyId     = currencyId          FROM dbo.Currencies           WHERE code = 'PTS';
        SELECT @rewardTypeId      = transactionTypeId   FROM dbo.TransactionTypes     WHERE code = 'reward';
        SELECT @commPlataformTypeId = transactionTypeId FROM dbo.TransactionTypes     WHERE code = 'commission';
        SELECT @commProposerTypeId  = transactionTypeId FROM dbo.TransactionTypes     WHERE code = 'commission';
        SELECT @refundTypeId        = transactionTypeId FROM dbo.TransactionTypes     WHERE code = 'refund';
        SELECT @outcomeId           = outcomeId         FROM dbo.PropositionOutcomes  WHERE code = @outcomeCode;

        IF @outcomeId IS NULL
            THROW 50070, 'outcomeCode inválido.', 1;

        -- Verificar estado de proposición
        SELECT @creatorId = creatorId, @subjectPlayerId = subjectPlayerId
        FROM dbo.Propositions WITH (UPDLOCK, ROWLOCK)
        WHERE propositionId = @propositionId AND propositionStatusId = @closedStatusId;

        IF @creatorId IS NULL
            THROW 50071, 'La proposición no existe o no está en estado closed.', 1;

        -- Leer configuración de comisiones vigente
        SELECT TOP 1
            @platformPtsPct = platformPointsCommissionPct,
            @proposerPtsPct = proposerPointsCommissionPct,
            @penaltyPct     = 15.00  -- no aplica aquí; es para unresolvable
        FROM dbo.PlatformConfig
        WHERE effectiveFrom <= GETUTCDATE()
          AND (effectiveTo IS NULL OR effectiveTo > GETUTCDATE())
        ORDER BY effectiveFrom DESC;

        -- Registrar outcome
        INSERT INTO dbo.PropositionOutcomeRecords (propositionId, outcomeId, validatedAt, validatedBy)
        VALUES (@propositionId, @outcomeId, GETUTCDATE(), @validatedBy);

        -- ==================== CASO: UNRESOLVABLE o CANCELLED → Reembolso total ====================
        IF @outcomeCode IN ('unresolvable', 'cancelled')
        BEGIN
            -- Reembolsar todos los predictores (liberar reservas)
            DECLARE cur_refund CURSOR LOCAL FAST_FORWARD FOR
                SELECT p.predictionId, p.walletId, p.predictorId, p.amountWagered, w.currencyId
                FROM dbo.Predictions p
                JOIN dbo.Wallets w ON p.walletId = w.walletId
                WHERE p.propositionId = @propositionId;

            OPEN cur_refund;
            FETCH NEXT FROM cur_refund INTO @predictionId, @predictorWalletId, @predictorPlayerId, @wagered, @walletCurrId;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT @balBefore = balance FROM dbo.Wallets WHERE walletId = @predictorWalletId;

                UPDATE dbo.Wallets
                SET balance = balance + @wagered, reservedBalance = reservedBalance - @wagered, updatedAt = GETUTCDATE()
                WHERE walletId = @predictorWalletId;

                INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                              referenceType, referenceId, correlationId, description, createdAt)
                VALUES (@predictorWalletId, @refundTypeId, @wagered, @balBefore, @balBefore + @wagered,
                        'proposition', @propositionId, @correlationId, 'Reembolso por proposición no resuelta', GETUTCDATE());

                SET @rewardTxId = SCOPE_IDENTITY();

                INSERT INTO dbo.PredictionResults (predictionId, isWinner, amountEarned, transactionId, resolvedAt)
                VALUES (@predictionId, 0, 0, @rewardTxId, GETUTCDATE());

                FETCH NEXT FROM cur_refund INTO @predictionId, @predictorWalletId, @predictorPlayerId, @wagered, @walletCurrId;
            END
            CLOSE cur_refund; DEALLOCATE cur_refund;

            -- Si es unresolvable, penalizar al sujeto (15% de sus puntos)
            IF @outcomeCode = 'unresolvable' AND @subjectPlayerId IS NOT NULL
            BEGIN
                DECLARE @subjectPtsWallet BIGINT;
                DECLARE @subjectPtsBal    DECIMAL(18,4);
                DECLARE @penaltyAmount    DECIMAL(18,4);
                DECLARE @penCatId         INT;

                SELECT @penCatId = penaltyCatalogId FROM dbo.PenaltyCatalog WHERE code = 'unresolvable_evidence'
                                                                              AND (effectiveTo IS NULL OR effectiveTo > GETUTCDATE());

                SELECT @subjectPtsWallet = walletId, @subjectPtsBal = balance
                FROM dbo.Wallets WHERE playerId = @subjectPlayerId AND currencyId = @ptsCurrencyId;

                SET @penaltyAmount = FLOOR(@subjectPtsBal * 0.15);

                IF @penaltyAmount > 0
                BEGIN
                    UPDATE dbo.Wallets SET balance = balance - @penaltyAmount, updatedAt = GETUTCDATE()
                    WHERE walletId = @subjectPtsWallet;

                    INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                                  referenceType, referenceId, correlationId, description, createdAt)
                    VALUES (@subjectPtsWallet, @commPlataformTypeId, -@penaltyAmount, @subjectPtsBal, @subjectPtsBal - @penaltyAmount,
                            'proposition', @propositionId, @correlationId, 'Penalización 15% por proposición no resuelta', GETUTCDATE());

                    SET @rewardTxId = SCOPE_IDENTITY();

                    INSERT INTO dbo.PenaltyTransactions (playerId, penaltyCatalogId, propositionId, transactionId, pointsDeducted, notes, appliedAt)
                    VALUES (@subjectPlayerId, @penCatId, @propositionId, @rewardTxId, CAST(@penaltyAmount AS BIGINT),
                            'Penalización automática por falta de evidencia válida', GETUTCDATE());
                END
            END
        END
        ELSE
        BEGIN
            -- ==================== CASO NORMAL: YES o NO ====================
            -- Determinar la opción ganadora
            SELECT @winningOptionId = predictionOptionId FROM dbo.PredictionOptions WHERE code = @outcomeCode;
            SELECT @losingOptionId  = predictionOptionId FROM dbo.PredictionOptions WHERE code = CASE WHEN @outcomeCode = 'yes' THEN 'no' ELSE 'yes' END;

            -- Calcular pozo total PTS y Money
            SELECT
                @totalPotPTS   = SUM(CASE WHEN w.currencyId = @ptsCurrencyId THEN p.amountWagered ELSE 0 END),
                @totalPotMoney = SUM(CASE WHEN w.currencyId <> @ptsCurrencyId THEN p.amountWagered ELSE 0 END)
            FROM dbo.Predictions p
            JOIN dbo.Wallets w ON p.walletId = w.walletId
            WHERE p.propositionId = @propositionId;

            -- Calcular total apostado por los ganadores (para proporción)
            SELECT
                @winnerTotalPTS   = SUM(CASE WHEN w.currencyId = @ptsCurrencyId THEN p.amountWagered ELSE 0 END),
                @winnerTotalMoney = SUM(CASE WHEN w.currencyId <> @ptsCurrencyId THEN p.amountWagered ELSE 0 END)
            FROM dbo.Predictions p
            JOIN dbo.Wallets w ON p.walletId = w.walletId
            WHERE p.propositionId = @propositionId AND p.predictionOptionId = @winningOptionId;

            -- Calcular comisiones sobre el pozo PTS
            SET @commPlatformPTS = FLOOR(@totalPotPTS * (@platformPtsPct / 100.0));
            SET @commProposerPTS = FLOOR(@totalPotPTS * (@proposerPtsPct / 100.0));

            DECLARE @netPotPTS DECIMAL(18,4) = @totalPotPTS - @commPlatformPTS - @commProposerPTS;

            -- Registrar comisión del creador en PTS (si aplica)
            IF @commProposerPTS > 0 AND @creatorId IS NOT NULL
            BEGIN
                SELECT @creatorWalletPTS = walletId, @creatorBalBefore = balance
                FROM dbo.Wallets WHERE playerId = @creatorId AND currencyId = @ptsCurrencyId;

                UPDATE dbo.Wallets SET balance = balance + @commProposerPTS, updatedAt = GETUTCDATE()
                WHERE walletId = @creatorWalletPTS;

                INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                              referenceType, referenceId, correlationId, description, createdAt)
                VALUES (@creatorWalletPTS, @commProposerTypeId, @commProposerPTS, @creatorBalBefore, @creatorBalBefore + @commProposerPTS,
                        'proposition', @propositionId, @correlationId, 'Comisión del creador de la proposición (PTS)', GETUTCDATE());

                SET @rewardTxId = SCOPE_IDENTITY();
                INSERT INTO dbo.RewardDistributions (propositionId, transactionId, distributionTypeId, percentageShare, createdAt)
                VALUES (@propositionId, @rewardTxId, @commProposerTypeId, @proposerPtsPct, GETUTCDATE());
            END

            -- Distribuir recompensas a los ganadores
            DECLARE cur_winners CURSOR LOCAL FAST_FORWARD FOR
                SELECT p.predictionId, p.walletId, p.predictorId, p.amountWagered,
                       p.predictionOptionId, w.currencyId
                FROM dbo.Predictions p
                JOIN dbo.Wallets w ON p.walletId = w.walletId
                WHERE p.propositionId = @propositionId;

            OPEN cur_winners;
            FETCH NEXT FROM cur_winners INTO @predictionId, @predictorWalletId, @predictorPlayerId,
                                             @wagered, @predOptId, @walletCurrId;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT @balBefore = balance FROM dbo.Wallets WHERE walletId = @predictorWalletId;

                IF @predOptId = @winningOptionId
                BEGIN
                    -- Ganador: devolver su apuesta + proporción del pozo neto
                    IF @walletCurrId = @ptsCurrencyId AND @winnerTotalPTS > 0
                        SET @earnedAmount = @wagered + FLOOR(@netPotPTS * (@wagered / @winnerTotalPTS));
                    ELSE IF @walletCurrId <> @ptsCurrencyId AND @winnerTotalMoney > 0
                        SET @earnedAmount = @wagered + (@totalPotMoney * (@wagered / @winnerTotalMoney));
                    ELSE
                        SET @earnedAmount = @wagered;

                    UPDATE dbo.Wallets
                    SET balance = balance + @earnedAmount, reservedBalance = reservedBalance - @wagered, updatedAt = GETUTCDATE()
                    WHERE walletId = @predictorWalletId;

                    INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                                  referenceType, referenceId, correlationId, description, createdAt)
                    VALUES (@predictorWalletId, @rewardTypeId, @earnedAmount, @balBefore, @balBefore + @earnedAmount,
                            'proposition', @propositionId, @correlationId, 'Premio por predicción ganadora', GETUTCDATE());

                    SET @rewardTxId = SCOPE_IDENTITY();
                    INSERT INTO dbo.RewardDistributions (propositionId, transactionId, distributionTypeId, percentageShare, createdAt)
                    VALUES (@propositionId, @rewardTxId, @rewardTypeId, NULL, GETUTCDATE());

                    INSERT INTO dbo.PredictionResults (predictionId, isWinner, amountEarned, transactionId, resolvedAt)
                    VALUES (@predictionId, 1, @earnedAmount, @rewardTxId, GETUTCDATE());
                END
                ELSE
                BEGIN
                    -- Perdedor: liberar reserva (el monto ya fue al pozo)
                    UPDATE dbo.Wallets
                    SET reservedBalance = reservedBalance - @wagered, updatedAt = GETUTCDATE()
                    WHERE walletId = @predictorWalletId;

                    INSERT INTO dbo.PredictionResults (predictionId, isWinner, amountEarned, transactionId, resolvedAt)
                    VALUES (@predictionId, 0, 0, NULL, GETUTCDATE());
                END

                FETCH NEXT FROM cur_winners INTO @predictionId, @predictorWalletId, @predictorPlayerId,
                                                 @wagered, @predOptId, @walletCurrId;
            END
            CLOSE cur_winners; DEALLOCATE cur_winners;
        END

        -- Cambiar estado de proposición a validated
        UPDATE dbo.Propositions SET propositionStatusId = @validatedStatusId WHERE propositionId = @propositionId;

        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@propositionId, @closedStatusId, @validatedStatusId, @validatedBy,
                CONCAT('Proposición validada. Outcome: ', @outcomeCode), GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 9: usp_DepositMoney
-- Registra un depósito de dinero real en el wallet de un jugador.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DepositMoney
    @playerId           BIGINT,
    @currencyCode       CHAR(10),
    @amount             DECIMAL(18,4),
    @paymentMethodId    BIGINT = NULL,
    @providerReference  NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @walletId       BIGINT;
    DECLARE @balBefore      DECIMAL(18,4);
    DECLARE @depositTypeId  INT;
    DECLARE @currencyId     INT;
    DECLARE @correlationId  UNIQUEIDENTIFIER = NEWID();
    DECLARE @txId           BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @depositTypeId = transactionTypeId FROM dbo.TransactionTypes WHERE code = 'deposit';
        SELECT @currencyId    = currencyId        FROM dbo.Currencies        WHERE code = @currencyCode;

        IF @currencyId IS NULL
            THROW 50080, 'Moneda inválida.', 1;

        SELECT @walletId = walletId, @balBefore = balance
        FROM dbo.Wallets WITH (UPDLOCK, ROWLOCK)
        WHERE playerId = @playerId AND currencyId = @currencyId;

        IF @walletId IS NULL
            THROW 50081, 'No existe wallet para esta moneda en el jugador.', 1;

        IF @amount <= 0
            THROW 50082, 'El monto del depósito debe ser positivo.', 1;

        UPDATE dbo.Wallets
        SET balance = balance + @amount, updatedAt = GETUTCDATE()
        WHERE walletId = @walletId;

        INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                      referenceType, referenceId, correlationId, description, createdAt)
        VALUES (@walletId, @depositTypeId, @amount, @balBefore, @balBefore + @amount,
                'payment_attempt', NULL, @correlationId, CONCAT('Depósito de ', @currencyCode), GETUTCDATE());

        SET @txId = SCOPE_IDENTITY();

        IF @paymentMethodId IS NOT NULL
        BEGIN
            INSERT INTO dbo.TransactionDetails (transactionId, paymentMethodId, providerReference, metadata, createdAt)
            VALUES (@txId, @paymentMethodId, @providerReference, NULL, GETUTCDATE());
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 10: usp_GetPlayerDashboard
-- Retorna el balance de un jugador junto con sus proposiciones y predicciones activas.
-- Usado por el frontend del MVP.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetPlayerDashboard
    @playerId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -- Balance por wallet
    SELECT
        c.code          AS currency,
        c.symbol        AS symbol,
        c.isVirtual,
        w.balance,
        w.reservedBalance,
        (w.balance + w.reservedBalance) AS totalBalance
    FROM dbo.Wallets w
    JOIN dbo.Currencies c ON w.currencyId = c.currencyId
    WHERE w.playerId = @playerId;

    -- Proposiciones activas donde el jugador es creador o sujeto
    SELECT
        p.propositionId,
        p.propositionText,
        ps.code         AS status,
        p.acceptedAt,
        p.predictionsCloseAt,
        creator.username AS creatorUsername,
        subject.username AS subjectUsername,
        p.createdAt
    FROM dbo.Propositions p
    JOIN dbo.PropositionStatuses ps  ON p.propositionStatusId = ps.propositionStatusId
    JOIN dbo.Players creator         ON p.creatorId = creator.playerId
    LEFT JOIN dbo.Players subject    ON p.subjectPlayerId = subject.playerId
    WHERE (p.creatorId = @playerId OR p.subjectPlayerId = @playerId)
      AND ps.code IN ('active', 'pending_acceptance', 'pending_vote', 'closed')
    ORDER BY p.createdAt DESC;

    -- Predicciones activas del jugador
    SELECT
        pr.predictionId,
        pr.propositionId,
        prop.propositionText,
        po.code         AS predictionOption,
        c.code          AS currency,
        pr.amountWagered,
        pr.lockedAt,
        pr.createdAt
    FROM dbo.Predictions pr
    JOIN dbo.Propositions prop      ON pr.propositionId = prop.propositionId
    JOIN dbo.PredictionOptions po   ON pr.predictionOptionId = po.predictionOptionId
    JOIN dbo.Wallets w              ON pr.walletId = w.walletId
    JOIN dbo.Currencies c           ON w.currencyId = c.currencyId
    WHERE pr.predictorId = @playerId
      AND pr.lockedAt IS NULL
    ORDER BY pr.createdAt DESC;
END;
GO

-- ==============================================================================
-- SP 11: usp_GetActivePropositions
-- Retorna proposiciones activas disponibles para hacer predicciones.
-- Utilizado en la pantalla principal del MVP.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetActivePropositions
    @pageNumber  INT = 1,
    @pageSize    INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.propositionId,
        p.propositionText,
        creator.username    AS creatorUsername,
        subject.username    AS subjectUsername,
        p.acceptedAt,
        p.predictionsCloseAt,
        p.createdAt,
        COUNT(pred.predictionId) AS totalPredictions
    FROM dbo.Propositions p
    JOIN dbo.PropositionStatuses ps ON p.propositionStatusId = ps.propositionStatusId
    JOIN dbo.Players creator        ON p.creatorId = creator.playerId
    LEFT JOIN dbo.Players subject   ON p.subjectPlayerId = subject.playerId
    LEFT JOIN dbo.Predictions pred  ON p.propositionId = pred.propositionId
    WHERE ps.code = 'active'
      AND p.predictionsCloseAt > GETUTCDATE()
    GROUP BY p.propositionId, p.propositionText, creator.username, subject.username,
             p.acceptedAt, p.predictionsCloseAt, p.createdAt
    ORDER BY p.createdAt DESC
    OFFSET (@pageNumber - 1) * @pageSize ROWS
    FETCH NEXT @pageSize ROWS ONLY;
END;
GO

-- ==============================================================================
-- SP 12: usp_GetPropositionResults
-- Retorna resultados de proposiciones ya validadas del jugador.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetPropositionResults
    @playerId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.propositionId,
        p.propositionText,
        po.code         AS outcome,
        por.validatedAt,
        pred.amountWagered,
        c.code          AS currency,
        COALESCE(pr.isWinner, 0)        AS isWinner,
        COALESCE(pr.amountEarned, 0)    AS amountEarned
    FROM dbo.Propositions p
    JOIN dbo.PropositionStatuses ps     ON p.propositionStatusId = ps.propositionStatusId
    JOIN dbo.PropositionOutcomeRecords por ON p.propositionId = por.propositionId
    JOIN dbo.PropositionOutcomes po     ON por.outcomeId = po.outcomeId
    JOIN dbo.Predictions pred           ON p.propositionId = pred.propositionId AND pred.predictorId = @playerId
    JOIN dbo.Wallets w                  ON pred.walletId = w.walletId
    JOIN dbo.Currencies c               ON w.currencyId = c.currencyId
    LEFT JOIN dbo.PredictionResults pr  ON pred.predictionId = pr.predictionId
    WHERE ps.code = 'validated'
    ORDER BY por.validatedAt DESC;
END;
GO
