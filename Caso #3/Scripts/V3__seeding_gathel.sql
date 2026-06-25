-- ==============================================================================
-- V3__seeding_gathel.sql
-- Gathel Gaming Platform — Seeding Masivo
-- Genera: 1000 jugadores, 5000 proposiciones, 250000 eventos, pagos correspondientes
-- Versionado con Flyway | SQL Server 2022
-- ==============================================================================
-- NOTA: Ejecutar DESPUÉS de V1__init_gathel.sql y V2__stored_procedures_gathel.sql
-- Este script es idempotente: verifica si los datos ya existen antes de insertar.
-- ==============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ==============================================================================
-- SECCIÓN 0: Datos base del sistema (catálogos y configuración inicial)
-- Se insertan sólo si no existen para que sea re-ejecutable.
-- ==============================================================================

-- TransactionTypes
IF NOT EXISTS (SELECT 1 FROM dbo.TransactionTypes WHERE code = 'deposit')
BEGIN
    INSERT INTO dbo.TransactionTypes (code, description, isDebit) VALUES
        ('deposit',           'Depósito de dinero real',                    0),
        ('withdrawal',        'Retiro de dinero real',                      1),
        ('wager',             'Apuesta en predicción',                      1),
        ('reward',            'Premio por predicción ganadora',             0),
        ('commission',        'Comisión de plataforma o creador',           1),
        ('penalty',           'Penalización de puntos',                     1),
        ('points_purchase',   'Compra de puntos virtuales',                 0),
        ('points_redemption', 'Canje de puntos por recompensa de partner',  1),
        ('refund',            'Reembolso por proposición no resuelta',      0);
END

-- PropositionStatuses
IF NOT EXISTS (SELECT 1 FROM dbo.PropositionStatuses WHERE code = 'pending_ai')
BEGIN
    INSERT INTO dbo.PropositionStatuses (code, description) VALUES
        ('pending_ai',          'En revisión por inteligencia artificial'),
        ('pending_vote',        'Disponible para votación de jugadores'),
        ('pending_acceptance',  'Esperando aceptación del sujeto'),
        ('active',              'Aceptada, con predicciones abiertas'),
        ('closed',              'Predicciones cerradas, pendiente de validación'),
        ('validated',           'Resultado validado y recompensas distribuidas'),
        ('cancelled',           'Cancelada antes de la validación'),
        ('rejected_ai',         'Rechazada por moderación de IA'),
        ('rejected_subject',    'Rechazada por el jugador sujeto');
END

-- PlayerStatuses
IF NOT EXISTS (SELECT 1 FROM dbo.PlayerStatuses WHERE code = 'active')
BEGIN
    INSERT INTO dbo.PlayerStatuses (code, description) VALUES
        ('active',    'Jugador activo'),
        ('suspended', 'Suspendido temporalmente'),
        ('banned',    'Baneado permanentemente'),
        ('inactive',  'Inactivo por tiempo prolongado');
END

-- PropositionOutcomes
IF NOT EXISTS (SELECT 1 FROM dbo.PropositionOutcomes WHERE code = 'yes')
BEGIN
    INSERT INTO dbo.PropositionOutcomes (code, description) VALUES
        ('yes',          'La proposición se cumplió'),
        ('no',           'La proposición no se cumplió'),
        ('cancelled',    'La proposición fue cancelada'),
        ('unresolvable', 'No fue posible validar el resultado');
END

-- PredictionOptions
IF NOT EXISTS (SELECT 1 FROM dbo.PredictionOptions WHERE code = 'yes')
BEGIN
    INSERT INTO dbo.PredictionOptions (code) VALUES ('yes'), ('no');
END

-- AIJobTypes
IF NOT EXISTS (SELECT 1 FROM dbo.AIJobTypes WHERE code = 'content_moderation')
BEGIN
    INSERT INTO dbo.AIJobTypes (code, description) VALUES
        ('content_moderation',   'Moderación de contenido de proposición'),
        ('evidence_validation',  'Validación de evidencia del resultado'),
        ('outcome_detection',    'Detección automática del resultado'),
        ('manipulation_detection','Detección de manipulación de evidencia');
END

-- AIJobStatuses
IF NOT EXISTS (SELECT 1 FROM dbo.AIJobStatuses WHERE code = 'queued')
BEGIN
    INSERT INTO dbo.AIJobStatuses (code) VALUES
        ('queued'), ('running'), ('completed'), ('failed'), ('cancelled');
END

-- PenaltyCatalog
IF NOT EXISTS (SELECT 1 FROM dbo.PenaltyCatalog WHERE code = 'proposition_rejection')
BEGIN
    INSERT INTO dbo.PenaltyCatalog (code, description, penaltyPercentage, fixedPointsAmount, effectiveFrom) VALUES
        ('proposition_rejection', 'Penalización por rechazar proposición ganadora', NULL, 1, GETUTCDATE()),
        ('unresolvable_evidence', 'Penalización por evidencia no resoluble (15% del balance)', 15.00, NULL, GETUTCDATE()),
        ('abuse',                 'Penalización por abuso del sistema', 25.00, NULL, GETUTCDATE()),
        ('false_evidence',        'Penalización por evidencia falsa', 20.00, NULL, GETUTCDATE()),
        ('late_validation',       'Penalización por validación tardía', NULL, 5, GETUTCDATE());
END

-- MediaTypes
IF NOT EXISTS (SELECT 1 FROM dbo.MediaTypes WHERE mimeType = 'image/png')
BEGIN
    INSERT INTO dbo.MediaTypes (mimeType, mediaExtension) VALUES
        ('image/png',   'png'),
        ('image/jpeg',  'jpg'),
        ('image/gif',   'gif'),
        ('video/mp4',   'mp4'),
        ('video/webm',  'webm'),
        ('application/pdf', 'pdf');
END

-- SocialPlatforms
IF NOT EXISTS (SELECT 1 FROM dbo.SocialPlatforms WHERE code = 'instagram')
BEGIN
    INSERT INTO dbo.SocialPlatforms (code, displayName, isActive) VALUES
        ('instagram', 'Instagram', 1),
        ('tiktok',    'TikTok',    1),
        ('twitter',   'X (Twitter)', 1),
        ('youtube',   'YouTube',   1);
END

-- AIProviders
IF NOT EXISTS (SELECT 1 FROM dbo.AIProviders WHERE code = 'anthropic')
BEGIN
    INSERT INTO dbo.AIProviders (code, displayName, apiBaseURL, isActive) VALUES
        ('anthropic', 'Anthropic',  'https://api.anthropic.com',          1),
        ('openai',    'OpenAI',     'https://api.openai.com',              1),
        ('google',    'Google AI',  'https://generativelanguage.googleapis.com', 1);
END

-- AIModels
IF NOT EXISTS (SELECT 1 FROM dbo.AIModels WHERE modelCode = 'claude-sonnet-4-6')
BEGIN
    DECLARE @anthropicId INT, @openaiId INT, @googleId INT;
    SELECT @anthropicId = providerId FROM dbo.AIProviders WHERE code = 'anthropic';
    SELECT @openaiId    = providerId FROM dbo.AIProviders WHERE code = 'openai';
    SELECT @googleId    = providerId FROM dbo.AIProviders WHERE code = 'google';

    INSERT INTO dbo.AIModels (providerId, modelCode, displayName, effectiveFrom, effectiveTo) VALUES
        (@anthropicId, 'claude-sonnet-4-6',   'Claude Sonnet 4.6',  '2024-01-01', NULL),
        (@anthropicId, 'claude-opus-4-6',     'Claude Opus 4.6',    '2024-01-01', NULL),
        (@openaiId,    'gpt-4o',              'GPT-4o',             '2024-01-01', NULL),
        (@googleId,    'gemini-1.5-pro',      'Gemini 1.5 Pro',     '2024-01-01', NULL);
END

-- Currencies
IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE code = 'PTS')
BEGIN
    INSERT INTO dbo.Currencies (code, currencyName, symbol, isVirtual, decimalPlaces) VALUES
        ('PTS',  'Puntos Gathel',    'PTS', 1, 0),
        ('USD',  'US Dollar',        '$',   0, 2),
        ('CRC',  'Colón Costarricense','₡', 0, 2),
        ('EUR',  'Euro',             '€',   0, 2);
END

-- Countries
IF NOT EXISTS (SELECT 1 FROM dbo.Countries WHERE isoCode = 'CRI')
BEGIN
    INSERT INTO dbo.Countries (countryName, isoCode) VALUES
        ('Costa Rica',    'CRI'),
        ('United States', 'USA'),
        ('Mexico',        'MEX'),
        ('Colombia',      'COL'),
        ('Argentina',     'ARG'),
        ('Spain',         'ESP'),
        ('Brazil',        'BRA'),
        ('Chile',         'CHL'),
        ('Peru',          'PER'),
        ('Panama',        'PAN');
END

-- PlatformConfig (configuración inicial)
IF NOT EXISTS (SELECT 1 FROM dbo.PlatformConfig WHERE effectiveTo IS NULL)
BEGIN
    INSERT INTO dbo.PlatformConfig (welcomePoints, minPointsReserveForProposition,
        platformPointsCommissionPct, platformMoneyCommissionPct,
        proposerPointsCommissionPct, streakBonusMultiplier, effectiveFrom, effectiveTo)
    VALUES (100, 15, 5.00, 5.00, 2.00, 1.00, GETUTCDATE(), NULL);
END
GO

-- ==============================================================================
-- SECCIÓN 1: 1000 JUGADORES
-- Genera usuarios con datos variados, wallets de PTS y USD, y sesiones.
-- ==============================================================================
DECLARE @i              INT = 1;
DECLARE @totalPlayers   INT = 1000;

DECLARE @activeStatusId INT;
DECLARE @ptsCurrencyId  INT;
DECLARE @usdCurrencyId  INT;
DECLARE @depositTypeId  INT;

SELECT @activeStatusId = playerStatusId FROM dbo.PlayerStatuses   WHERE code = 'active';
SELECT @ptsCurrencyId  = currencyId     FROM dbo.Currencies       WHERE code = 'PTS';
SELECT @usdCurrencyId  = currencyId     FROM dbo.Currencies       WHERE code = 'USD';
SELECT @depositTypeId  = transactionTypeId FROM dbo.TransactionTypes WHERE code = 'deposit';

-- Verificar si ya existen jugadores de seeding
IF (SELECT COUNT(1) FROM dbo.Players WHERE username LIKE 'player_%') >= @totalPlayers
BEGIN
    PRINT 'Jugadores ya sembrados. Se omite la sección de Players.';
    GOTO skip_players;
END

-- Nombres base para generar usernames y emails realistas
DECLARE @firstNames TABLE (idx INT IDENTITY(1,1), name NVARCHAR(50));
INSERT INTO @firstNames (name) VALUES
    ('Sofia'),('Diego'),('Valeria'),('Carlos'),('Daniela'),('Miguel'),('Gabriela'),('Andres'),
    ('Camila'),('Luis'),('Isabella'),('Juan'),('Laura'),('Roberto'),('Mariana'),('Alejandro'),
    ('Paula'),('Fernando'),('Ana'),('Ricardo'),('Natalia'),('Sergio'),('Monica'),('Eduardo'),
    ('Paola'),('Jorge'),('Diana'),('Marcos'),('Elena'),('Antonio'),('Sara'),('Victor'),
    ('Fernanda'),('Pablo'),('Lucia'),('Hector'),('Adriana'),('Oscar'),('Claudia'),('Manuel');

DECLARE @lastNames TABLE (idx INT IDENTITY(1,1), name NVARCHAR(50));
INSERT INTO @lastNames (name) VALUES
    ('Garcia'),('Rodriguez'),('Martinez'),('Lopez'),('Gonzalez'),('Perez'),('Sanchez'),('Ramirez'),
    ('Torres'),('Flores'),('Rivera'),('Gomez'),('Diaz'),('Reyes'),('Cruz'),('Morales'),('Ortiz'),
    ('Gutierrez'),('Chavez'),('Ruiz'),('Mendez'),('Castro'),('Vargas'),('Rojas'),('Herrera'),
    ('Medina'),('Aguilar'),('Jimenez'),('Moreno'),('Soto'),('Navarro'),('Ramos'),('Vega'),
    ('Campos'),('Fuentes'),('Rios'),('Cabrera'),('Silva'),('Delgado'),('Nunez');

DECLARE @countryIds TABLE (idx INT IDENTITY(1,1), countryId INT);
INSERT INTO @countryIds (countryId) SELECT countryId FROM dbo.Countries;

DECLARE @username       NVARCHAR(50);
DECLARE @email          NVARCHAR(255);
DECLARE @newPlayerId    BIGINT;
DECLARE @walletId       BIGINT;
DECLARE @ptsBalance     DECIMAL(18,4);
DECLARE @usdBalance     DECIMAL(18,4);
DECLARE @countryId      INT;
DECLARE @statusId       INT;
DECLARE @fn             NVARCHAR(50);
DECLARE @ln             NVARCHAR(50);
DECLARE @correlationId  UNIQUEIDENTIFIER;
DECLARE @fnCount        INT = (SELECT COUNT(1) FROM @firstNames);
DECLARE @lnCount        INT = (SELECT COUNT(1) FROM @lastNames);
DECLARE @countryCount   INT = (SELECT COUNT(1) FROM @countryIds);
DECLARE @ptsWalletId    BIGINT;
DECLARE @usdWalletId    BIGINT;

-- Tabla temporal para mapear player_i → playerId real
CREATE TABLE #PlayerMap (seqNum INT, playerId BIGINT, ptsWalletId BIGINT, usdWalletId BIGINT);

WHILE @i <= @totalPlayers
BEGIN
    SET @fn        = (SELECT name FROM @firstNames WHERE idx = (@i % @fnCount) + 1);
    SET @ln        = (SELECT name FROM @lastNames  WHERE idx = (@i % @lnCount) + 1);
    SET @username  = LOWER(@fn) + '_' + LOWER(@ln) + '_' + CAST(@i AS NVARCHAR(10));
    SET @email     = LOWER(@fn) + '.' + LOWER(@ln) + CAST(@i AS NVARCHAR(10)) + '@gathel.dev';
    SET @countryId = (SELECT countryId FROM @countryIds WHERE idx = (@i % @countryCount) + 1);
    SET @ptsBalance = 100 + (ABS(CHECKSUM(NEWID())) % 900);  -- 100–999 PTS iniciales
    SET @usdBalance = CAST((ABS(CHECKSUM(NEWID())) % 500)  AS DECIMAL(18,4));  -- 0–499 USD

    -- Algunos jugadores con estado diferente (5% suspendidos, 2% baneados)
    IF @i % 20 = 0
        SET @statusId = (SELECT playerStatusId FROM dbo.PlayerStatuses WHERE code = 'suspended');
    ELSE IF @i % 50 = 0
        SET @statusId = (SELECT playerStatusId FROM dbo.PlayerStatuses WHERE code = 'banned');
    ELSE
        SET @statusId = @activeStatusId;

    INSERT INTO dbo.Players (username, email, passwordHash, passwordSalt, playerStatusId,
                              countryId, isVerified, createdAt)
    VALUES (
        @username, @email,
        CAST(HASHBYTES('SHA2_256', @username + 'salt' + CAST(@i AS NVARCHAR)) AS VARBINARY(64)),
        CAST(HASHBYTES('SHA2_256', CAST(@i AS NVARCHAR) + 'randomsalt') AS VARBINARY(32)),
        @statusId,
        @countryId,
        CASE WHEN @i % 3 = 0 THEN 1 ELSE 0 END,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETUTCDATE())
    );
    SET @newPlayerId = SCOPE_IDENTITY();

    -- Wallet PTS
    INSERT INTO dbo.Wallets (playerId, currencyId, balance, reservedBalance, createdAt)
    VALUES (@newPlayerId, @ptsCurrencyId, @ptsBalance, 0, GETUTCDATE());
    SET @ptsWalletId = SCOPE_IDENTITY();

    -- Transacción de bienvenida PTS
    SET @correlationId = NEWID();
    INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                  referenceType, referenceId, correlationId, description, createdAt)
    VALUES (@ptsWalletId, @depositTypeId, @ptsBalance, 0, @ptsBalance,
            'player', @newPlayerId, @correlationId, 'Puntos iniciales de bienvenida', GETUTCDATE());

    -- Wallet USD
    INSERT INTO dbo.Wallets (playerId, currencyId, balance, reservedBalance, createdAt)
    VALUES (@newPlayerId, @usdCurrencyId, @usdBalance, 0, GETUTCDATE());
    SET @usdWalletId = SCOPE_IDENTITY();

    -- Depósito USD (si tiene saldo)
    IF @usdBalance > 0
    BEGIN
        INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                      referenceType, referenceId, correlationId, description, createdAt)
        VALUES (@usdWalletId, @depositTypeId, @usdBalance, 0, @usdBalance,
                'player', @newPlayerId, NEWID(), 'Depósito inicial USD', GETUTCDATE());
    END

    INSERT INTO #PlayerMap (seqNum, playerId, ptsWalletId, usdWalletId)
    VALUES (@i, @newPlayerId, @ptsWalletId, @usdWalletId);

    SET @i = @i + 1;
END

PRINT CONCAT('Players insertados: ', @totalPlayers);

skip_players:
GO

-- ==============================================================================
-- SECCIÓN 2: CUENTAS SOCIALES (opcional, para realismo)
-- Vincula 1-2 redes sociales a cada jugador activo.
-- ==============================================================================
DECLARE @socialPlatforms TABLE (platformId INT, code NVARCHAR(50));
INSERT INTO @socialPlatforms SELECT platformId, code FROM dbo.SocialPlatforms WHERE isActive = 1;
DECLARE @platCount INT = (SELECT COUNT(1) FROM @socialPlatforms);

DECLARE @playerIds TABLE (seq INT IDENTITY(1,1), playerId BIGINT);
INSERT INTO @playerIds SELECT TOP 1000 playerId FROM dbo.Players ORDER BY playerId;

DECLARE @si INT = 1;
DECLARE @pid BIGINT;
DECLARE @platId INT;

WHILE @si <= (SELECT MAX(seq) FROM @playerIds)
BEGIN
    SELECT @pid = playerId FROM @playerIds WHERE seq = @si;

    -- Red social principal
    SELECT @platId = platformId FROM @socialPlatforms WHERE platformId = (@si % @platCount) + 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.SocialAccounts WHERE playerId = @pid AND platformId = @platId)
    BEGIN
        INSERT INTO dbo.SocialAccounts (playerId, platformId, externalUserId, username, profileURL, linkedAt)
        VALUES (@pid, @platId,
                CONCAT('ext_', @pid, '_', @platId),
                (SELECT username FROM dbo.Players WHERE playerId = @pid),
                CONCAT('https://social.example.com/user/', @pid),
                DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 180, GETUTCDATE()));
    END

    SET @si = @si + 1;
END

PRINT 'SocialAccounts insertados.';
GO

-- ==============================================================================
-- SECCIÓN 3: 5000 PROPOSICIONES
-- Distribución realista de estados.
-- ==============================================================================
DECLARE @totalProps         INT = 5000;
DECLARE @pj                 INT = 1;

-- Mapas de IDs de estado
DECLARE @statusActive       INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'active');
DECLARE @statusClosed       INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'closed');
DECLARE @statusValidated    INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'validated');
DECLARE @statusPendingAI    INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_ai');
DECLARE @statusPendingAcc   INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_acceptance');
DECLARE @statusRejSubj      INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'rejected_subject');
DECLARE @statusCancelled    INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'cancelled');

-- Tabla de textos de proposiciones predefinidos (variados y realistas)
DECLARE @propTexts TABLE (idx INT IDENTITY(1,1), txt NVARCHAR(500));
INSERT INTO @propTexts (txt) VALUES
    ('Completará un maratón este trimestre'),
    ('Publicará una foto de su desayuno esta semana'),
    ('Viajará fuera del país en el próximo mes'),
    ('Subirá al menos 10 publicaciones en Instagram este mes'),
    ('Irá al gimnasio 5 veces esta semana'),
    ('Adoptará una mascota antes de fin de año'),
    ('Aprenderá a cocinar un platillo nuevo este fin de semana'),
    ('Leerá un libro completo este mes'),
    ('Completará un curso en línea en las próximas 4 semanas'),
    ('Asistirá a un evento musical en vivo este mes'),
    ('Cambiará su foto de perfil antes del viernes'),
    ('Publicará un video de TikTok con más de 1000 vistas'),
    ('Hará ejercicio al aire libre 3 veces esta semana'),
    ('Iniciará un emprendimiento en los próximos 6 meses'),
    ('Visitará a su familia este fin de semana'),
    ('Intentará una nueva receta de repostería'),
    ('Participará en una competencia deportiva local'),
    ('Publicará una historia de Instagram antes de medianoche'),
    ('Completará los 10,000 pasos diarios esta semana'),
    ('Organizará una reunión social con amigos este mes'),
    ('Hará una donación a una causa benéfica este mes'),
    ('Empezará a aprender un idioma nuevo'),
    ('Realizará un cambio de look antes del fin de mes'),
    ('Compartirá un logro académico o profesional'),
    ('Dedicará tiempo voluntario a su comunidad este mes');

DECLARE @propTextCount INT = (SELECT COUNT(1) FROM @propTexts);

-- Recuperar player IDs activos para asignar como creadores/sujetos
DECLARE @activePlayers TABLE (seq INT IDENTITY(1,1), playerId BIGINT);
INSERT INTO @activePlayers
    SELECT TOP 900 p.playerId FROM dbo.Players p
    JOIN dbo.PlayerStatuses ps ON p.playerStatusId = ps.playerStatusId
    WHERE ps.code = 'active'
    ORDER BY p.playerId;

DECLARE @activePlayerCount INT = (SELECT COUNT(1) FROM @activePlayers);

-- Tabla de IDs de proposiciones creadas (para luego crear eventos y predicciones)
CREATE TABLE #PropMap (
    seqNum          INT,
    propositionId   BIGINT,
    creatorId       BIGINT,
    subjectId       BIGINT,
    statusId        INT,
    createdAt       DATETIME2,
    predictionsCloseAt DATETIME2
);

-- Modelo de distribución de estados:
--   40% validated (históricas, completamente procesadas)
--   20% closed    (en espera de validación)
--   20% active    (abiertas para predicciones)
--   10% pending_acceptance
--   5%  pending_ai
--   3%  rejected_subject
--   2%  cancelled

DECLARE @propStatus     INT;
DECLARE @creatorSeq     INT;
DECLARE @subjectSeq     INT;
DECLARE @cId            BIGINT;
DECLARE @sId            BIGINT;
DECLARE @propText       NVARCHAR(500);
DECLARE @createdAt      DATETIME2;
DECLARE @closeAt        DATETIME2;
DECLARE @acceptedAt     DATETIME2;
DECLARE @newPropId      BIGINT;
DECLARE @rnd            INT;

WHILE @pj <= @totalProps
BEGIN
    -- Determinar estado según distribución
    SET @rnd = @pj % 100;
    IF      @rnd < 40 SET @propStatus = @statusValidated;
    ELSE IF @rnd < 60 SET @propStatus = @statusClosed;
    ELSE IF @rnd < 80 SET @propStatus = @statusActive;
    ELSE IF @rnd < 90 SET @propStatus = @statusPendingAcc;
    ELSE IF @rnd < 95 SET @propStatus = @statusPendingAI;
    ELSE IF @rnd < 98 SET @propStatus = @statusRejSubj;
    ELSE               SET @propStatus = @statusCancelled;

    -- Elegir creador (cualquier jugador activo)
    SET @creatorSeq = (@pj % @activePlayerCount) + 1;
    SELECT @cId = playerId FROM @activePlayers WHERE seq = @creatorSeq;

    -- Sujeto: 70% de proposiciones tienen sujeto distinto al creador
    IF @pj % 10 < 7
    BEGIN
        SET @subjectSeq = ((@pj + 3) % @activePlayerCount) + 1;
        SELECT @sId = playerId FROM @activePlayers WHERE seq = @subjectSeq;
        IF @sId = @cId SET @sId = NULL; -- evitar autorechazo forzado
    END
    ELSE
        SET @sId = NULL; -- proposición sobre sí mismo (30%)

    SET @propText = (SELECT txt FROM @propTexts WHERE idx = (@pj % @propTextCount) + 1);

    -- Timestamps coherentes: proposiciones más viejas para estados avanzados
    IF @propStatus = @statusValidated
    BEGIN
        SET @createdAt = DATEADD(DAY, -(30 + ABS(CHECKSUM(NEWID())) % 335), GETUTCDATE());
        SET @acceptedAt = DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 12, @createdAt);
        SET @closeAt    = DATEADD(DAY, 1 + ABS(CHECKSUM(NEWID())) % 7, @acceptedAt);
    END
    ELSE IF @propStatus = @statusClosed
    BEGIN
        SET @createdAt  = DATEADD(DAY, -(5 + ABS(CHECKSUM(NEWID())) % 25), GETUTCDATE());
        SET @acceptedAt = DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 6, @createdAt);
        SET @closeAt    = DATEADD(HOUR, -1, GETUTCDATE());  -- ya cerró
    END
    ELSE IF @propStatus = @statusActive
    BEGIN
        SET @createdAt  = DATEADD(HOUR, -(ABS(CHECKSUM(NEWID())) % 48), GETUTCDATE());
        SET @acceptedAt = DATEADD(HOUR,  ABS(CHECKSUM(NEWID())) % 4, @createdAt);
        SET @closeAt    = DATEADD(HOUR,  6 + ABS(CHECKSUM(NEWID())) % 72, GETUTCDATE());
    END
    ELSE
    BEGIN
        SET @createdAt  = DATEADD(HOUR, -(ABS(CHECKSUM(NEWID())) % 24), GETUTCDATE());
        SET @acceptedAt = NULL;
        SET @closeAt    = NULL;
    END

    INSERT INTO dbo.Propositions (creatorId, subjectPlayerId, propositionText, propositionStatusId,
                                  aiJobId, winningVoteId, acceptedAt, predictionsCloseAt, createdAt)
    VALUES (@cId, @sId, @propText, @propStatus, NULL, NULL, @acceptedAt, @closeAt, @createdAt);

    SET @newPropId = SCOPE_IDENTITY();

    INSERT INTO #PropMap (seqNum, propositionId, creatorId, subjectId, statusId, createdAt, predictionsCloseAt)
    VALUES (@pj, @newPropId, @cId, @sId, @propStatus, @createdAt, @closeAt);

    SET @pj = @pj + 1;
END

PRINT CONCAT('Propositions insertadas: ', @totalProps);
GO

-- ==============================================================================
-- SECCIÓN 4: VOTES para proposiciones en pending_acceptance/validated/closed
-- ==============================================================================
DECLARE @voteProps TABLE (seq INT IDENTITY(1,1), propositionId BIGINT, creatorId BIGINT);
INSERT INTO @voteProps
    SELECT pm.propositionId, pm.creatorId
    FROM #PropMap pm
    WHERE pm.statusId IN (
        SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code IN ('pending_acceptance','active','closed','validated')
    );

DECLARE @voteCount  INT = (SELECT COUNT(1) FROM @voteProps);
DECLARE @vi         INT = 1;
DECLARE @vpId       BIGINT;
DECLARE @vCreator   BIGINT;
DECLARE @votesPerProp INT;
DECLARE @vj         INT;
DECLARE @voterSeq   INT;
DECLARE @voterId    BIGINT;

DECLARE @voterPool TABLE (seq INT IDENTITY(1,1), playerId BIGINT);
INSERT INTO @voterPool SELECT TOP 500 playerId FROM dbo.Players ORDER BY playerId;
DECLARE @voterPoolSize INT = (SELECT COUNT(1) FROM @voterPool);

WHILE @vi <= @voteCount
BEGIN
    SELECT @vpId = propositionId, @vCreator = creatorId FROM @voteProps WHERE seq = @vi;
    SET @votesPerProp = 3 + (ABS(CHECKSUM(NEWID())) % 12); -- 3-14 votos por proposición
    SET @vj = 0;

    WHILE @vj < @votesPerProp
    BEGIN
        SET @voterSeq = ((@vi * 7 + @vj * 13) % @voterPoolSize) + 1;
        SELECT @voterId = playerId FROM @voterPool WHERE seq = @voterSeq;

        -- No se vota a si mismo
        IF @voterId <> @vCreator AND
           NOT EXISTS (SELECT 1 FROM dbo.PropositionVotes WHERE propositionId = @vpId AND voterId = @voterId)
        BEGIN
            INSERT INTO dbo.PropositionVotes (propositionId, voterId, voteValue, createdAt)
            VALUES (@vpId, @voterId,
                    CASE WHEN (@vj % 3 = 0) THEN 'no' ELSE 'yes' END,
                    GETUTCDATE());
        END
        SET @vj = @vj + 1;
    END

    SET @vi = @vi + 1;
END
PRINT 'PropositionVotes insertados.';
GO

-- ==============================================================================
-- SECCIÓN 5: 250,000 PROPOSITION EVENTS
-- Genera eventos de transición de estado coherentes con el estado final.
-- Distribuidos entre las 5000 proposiciones (≈50 eventos por proposición).
-- ==============================================================================

-- Estados para IDs
DECLARE @evtPendingAI   INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_ai');
DECLARE @evtPendingVote INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_vote');
DECLARE @evtPendingAcc  INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'pending_acceptance');
DECLARE @evtActive      INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'active');
DECLARE @evtClosed      INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'closed');
DECLARE @evtValidated   INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'validated');
DECLARE @evtRejSubj     INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'rejected_subject');
DECLARE @evtCancelled   INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'cancelled');

DECLARE @evtPool TABLE (seq INT IDENTITY(1,1), propositionId BIGINT, statusId INT, createdAt DATETIME2, creatorId BIGINT);
INSERT INTO @evtPool SELECT propositionId, statusId, createdAt, creatorId FROM #PropMap ORDER BY seqNum;

DECLARE @totalEvtTarget     INT = 250000;
DECLARE @propsCount         INT = (SELECT COUNT(1) FROM @evtPool);
-- Eventos por proposición: base = 50, con variación
DECLARE @baseEvtPerProp     INT = @totalEvtTarget / @propsCount;  -- ~50
DECLARE @ei                 INT = 1;
DECLARE @eTotalInserted     INT = 0;
DECLARE @epId               BIGINT;
DECLARE @epStatusId         INT;
DECLARE @epCreatedAt        DATETIME2;
DECLARE @epCreatorId        BIGINT;
DECLARE @evtCount           INT;
DECLARE @ej                 INT;
DECLARE @evtFromId          INT;
DECLARE @evtToId            INT;
DECLARE @evtTs              DATETIME2;
DECLARE @deltaMinutes       INT;
DECLARE @noteIdx            INT;
DECLARE @note               NVARCHAR(500);

WHILE @ei <= @propsCount AND @eTotalInserted < @totalEvtTarget
BEGIN
    SELECT @epId = propositionId, @epStatusId = statusId,
           @epCreatedAt = createdAt, @epCreatorId = creatorId
    FROM @evtPool WHERE seq = @ei;

    -- Varía entre base-10 y base+10 eventos por proposición
    SET @evtCount = @baseEvtPerProp - 10 + (ABS(CHECKSUM(NEWID())) % 21);
    IF @eTotalInserted + @evtCount > @totalEvtTarget
        SET @evtCount = @totalEvtTarget - @eTotalInserted;

    SET @ej = 0;
    SET @evtTs = @epCreatedAt;

    -- Siempre hay un evento inicial NULL → pending_ai
    INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
    VALUES (@epId, NULL, @evtPendingAI, @epCreatorId, 'Proposición creada y enviada a moderación AI', @evtTs);
    SET @eTotalInserted = @eTotalInserted + 1;
    SET @ej = @ej + 1;

    -- Segundo evento: AI aprobó → pending_vote
    SET @deltaMinutes = 2 + ABS(CHECKSUM(NEWID())) % 8;
    SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);
    INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
    VALUES (@epId, @evtPendingAI, @evtPendingVote, NULL, 'Moderación AI: contenido aprobado', @evtTs);
    SET @eTotalInserted = @eTotalInserted + 1;
    SET @ej = @ej + 1;

    -- Tercer evento: votación terminó → pending_acceptance (si el estado avanzó)
    IF @epStatusId NOT IN (@evtPendingAI)
    BEGIN
        SET @deltaMinutes = 60 + ABS(CHECKSUM(NEWID())) % 1380; -- 1-24 horas
        SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@epId, @evtPendingVote, @evtPendingAcc, NULL, 'Período de votación cerrado, proposición enviada al sujeto', @evtTs);
        SET @eTotalInserted = @eTotalInserted + 1;
        SET @ej = @ej + 1;
    END

    -- Cuarto evento según el estado final
    IF @epStatusId = @evtActive OR @epStatusId = @evtClosed OR @epStatusId = @evtValidated
    BEGIN
        SET @deltaMinutes = 10 + ABS(CHECKSUM(NEWID())) % 120;
        SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@epId, @evtPendingAcc, @evtActive, NULL, 'Sujeto aceptó la proposición. Predicciones habilitadas.', @evtTs);
        SET @eTotalInserted = @eTotalInserted + 1;
        SET @ej = @ej + 1;
    END
    ELSE IF @epStatusId = @evtRejSubj
    BEGIN
        SET @deltaMinutes = 10 + ABS(CHECKSUM(NEWID())) % 60;
        SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@epId, @evtPendingAcc, @evtRejSubj, NULL, 'Sujeto rechazó la proposición. -1 PTS aplicado.', @evtTs);
        SET @eTotalInserted = @eTotalInserted + 1;
        SET @ej = @ej + 1;
    END
    ELSE IF @epStatusId = @evtCancelled
    BEGIN
        SET @deltaMinutes = 5 + ABS(CHECKSUM(NEWID())) % 30;
        SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@epId, @evtPendingAcc, @evtCancelled, NULL, 'Proposición cancelada por el sistema.', @evtTs);
        SET @eTotalInserted = @eTotalInserted + 1;
        SET @ej = @ej + 1;
    END

    IF @epStatusId = @evtClosed OR @epStatusId = @evtValidated
    BEGIN
        SET @deltaMinutes = 1440 + ABS(CHECKSUM(NEWID())) % 4320; -- 1-4 días activa
        SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@epId, @evtActive, @evtClosed, NULL, 'Cierre automático del período de predicciones.', @evtTs);
        SET @eTotalInserted = @eTotalInserted + 1;
        SET @ej = @ej + 1;
    END

    IF @epStatusId = @evtValidated
    BEGIN
        SET @deltaMinutes = 60 + ABS(CHECKSUM(NEWID())) % 1440;
        SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);
        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@epId, @evtClosed, @evtValidated, NULL, 'Resultado validado por AI. Recompensas distribuidas.', @evtTs);
        SET @eTotalInserted = @eTotalInserted + 1;
        SET @ej = @ej + 1;
    END

    -- Eventos adicionales de actividad (notificaciones internas, actualizaciones de AI, etc.)
    -- para llegar al objetivo de ~50 eventos por proposición
    WHILE @ej < @evtCount AND @eTotalInserted < @totalEvtTarget
    BEGIN
        SET @deltaMinutes = ABS(CHECKSUM(NEWID())) % 480;
        SET @evtTs = DATEADD(MINUTE, @deltaMinutes, @evtTs);

        -- Ciclar entre eventos de monitoreo según el estado final
        SET @noteIdx = @ej % 8;
        SET @note =
            CASE @noteIdx
                WHEN 0 THEN 'Sistema: verificación periódica del estado de la proposición'
                WHEN 1 THEN 'AI: re-análisis de contenido por actualización de modelo'
                WHEN 2 THEN 'Sistema: alerta de proximidad al cierre de predicciones'
                WHEN 3 THEN 'Sistema: notificación enviada a participantes'
                WHEN 4 THEN 'Sistema: actualización de conteo de predicciones'
                WHEN 5 THEN 'Sistema: sincronización de redes sociales del sujeto'
                WHEN 6 THEN 'Sistema: verificación de elegibilidad de predictores'
                ELSE        'Sistema: heartbeat de monitoreo de proposición activa'
            END;

        INSERT INTO dbo.PropositionEvents (propositionId, fromStatusId, toStatusId, triggeredBy, notes, createdAt)
        VALUES (@epId, @epStatusId, @epStatusId, NULL, @note, @evtTs);

        SET @eTotalInserted = @eTotalInserted + 1;
        SET @ej = @ej + 1;
    END

    SET @ei = @ei + 1;
END

PRINT CONCAT('PropositionEvents insertados: ', @eTotalInserted);
GO

-- ==============================================================================
-- SECCIÓN 6: PREDICCIONES sobre proposiciones activas, cerradas y validadas
-- ==============================================================================
DECLARE @predProps TABLE (seq INT IDENTITY(1,1), propositionId BIGINT, statusId INT);
INSERT INTO @predProps
    SELECT pm.propositionId, pm.statusId FROM #PropMap pm
    WHERE pm.statusId IN (
        SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code IN ('active','closed','validated')
    )
    ORDER BY pm.seqNum;

DECLARE @predPropsCount INT = (SELECT COUNT(1) FROM @predProps);
DECLARE @ppi INT = 1;
DECLARE @ppId BIGINT;
DECLARE @ppStatus INT;
DECLARE @predictorsPerProp INT;
DECLARE @ppj INT;
DECLARE @predictorSeq INT;
DECLARE @predictorId BIGINT;
DECLARE @usePoints BIT;
DECLARE @predWalletId BIGINT;
DECLARE @predAmount DECIMAL(18,4);
DECLARE @predOptId INT;
DECLARE @yesOptId INT = (SELECT predictionOptionId FROM dbo.PredictionOptions WHERE code = 'yes');
DECLARE @noOptId  INT = (SELECT predictionOptionId FROM dbo.PredictionOptions WHERE code = 'no');
DECLARE @wagerTypeId INT = (SELECT transactionTypeId FROM dbo.TransactionTypes WHERE code = 'wager');
DECLARE @ptsCurrId   INT = (SELECT currencyId FROM dbo.Currencies WHERE code = 'PTS');
DECLARE @usdCurrId   INT = (SELECT currencyId FROM dbo.Currencies WHERE code = 'USD');
DECLARE @walBefore   DECIMAL(18,4);
DECLARE @newPredId   BIGINT;

DECLARE @predPlayerPool TABLE (seq INT IDENTITY(1,1), playerId BIGINT, ptsWalletId BIGINT, usdWalletId BIGINT);
INSERT INTO @predPlayerPool (playerId, ptsWalletId, usdWalletId)
    SELECT p.playerId, wPTS.walletId, wUSD.walletId
    FROM dbo.Players p
    JOIN dbo.Wallets wPTS ON p.playerId = wPTS.playerId AND wPTS.currencyId = @ptsCurrId
    JOIN dbo.Wallets wUSD ON p.playerId = wUSD.playerId AND wUSD.currencyId = @usdCurrId
    ORDER BY p.playerId;

DECLARE @predPoolSize INT = (SELECT COUNT(1) FROM @predPlayerPool);

WHILE @ppi <= @predPropsCount
BEGIN
    SELECT @ppId = propositionId, @ppStatus = statusId FROM @predProps WHERE seq = @ppi;
    SET @predictorsPerProp = 5 + (ABS(CHECKSUM(NEWID())) % 46); -- 5-50 predictores
    SET @ppj = 0;

    WHILE @ppj < @predictorsPerProp
    BEGIN
        SET @predictorSeq = ((@ppi * 17 + @ppj * 11) % @predPoolSize) + 1;
        SELECT @predictorId = playerId, @predWalletId = ptsWalletId
        FROM @predPlayerPool WHERE seq = @predictorSeq;

        -- 60% predicciones con PTS, 40% con USD
        SET @usePoints = CASE WHEN (@ppj % 5 < 3) THEN 1 ELSE 0 END;

        IF @usePoints = 0
            SELECT @predWalletId = usdWalletId FROM @predPlayerPool WHERE seq = @predictorSeq;

        -- Evitar duplicados (propositionId, predictorId, walletId)
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Predictions
            WHERE propositionId = @ppId AND predictorId = @predictorId AND walletId = @predWalletId
        )
        BEGIN
            -- Monto: PTS siempre 1, USD entre 1.00 y 50.00
            IF @usePoints = 1
                SET @predAmount = 1;
            ELSE
                SET @predAmount = CAST(1 + (ABS(CHECKSUM(NEWID())) % 50) AS DECIMAL(18,4));

            -- Verificar saldo disponible
            SELECT @walBefore = balance FROM dbo.Wallets WHERE walletId = @predWalletId;

            IF @walBefore >= @predAmount
            BEGIN
                -- 55% predicen YES, 45% NO
                SET @predOptId = CASE WHEN (@ppj % 20 < 11) THEN @yesOptId ELSE @noOptId END;

                -- Insertar predicción
                INSERT INTO dbo.Predictions (propositionId, predictorId, predictionOptionId, walletId,
                                             amountWagered, lockedAt, createdAt)
                VALUES (@ppId, @predictorId, @predOptId, @predWalletId, @predAmount,
                        CASE WHEN @ppStatus IN (
                            SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code IN ('closed','validated')
                        ) THEN DATEADD(MINUTE, -5, GETUTCDATE()) ELSE NULL END,
                        GETUTCDATE());
                SET @newPredId = SCOPE_IDENTITY();

                -- Actualizar wallet (reservar)
                UPDATE dbo.Wallets
                SET balance = balance - @predAmount,
                    reservedBalance = reservedBalance + @predAmount,
                    updatedAt = GETUTCDATE()
                WHERE walletId = @predWalletId;

                -- Transacción de wager
                INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                              referenceType, referenceId, correlationId, description, createdAt)
                VALUES (@predWalletId, @wagerTypeId, -@predAmount, @walBefore, @walBefore - @predAmount,
                        'prediction', @newPredId, NEWID(),
                        CONCAT('Apuesta en proposición #', @ppId), GETUTCDATE());

                -- Historial de wager
                INSERT INTO dbo.PredictionWagerHistory (predictionId, additionalAmount, totalAfter, createdAt)
                VALUES (@newPredId, @predAmount, @predAmount, GETUTCDATE());
            END
        END

        SET @ppj = @ppj + 1;
    END

    SET @ppi = @ppi + 1;
END

PRINT 'Predictions insertadas.';
GO

-- ==============================================================================
-- SECCIÓN 7: OUTCOMES y PREDICTION RESULTS para proposiciones validated
-- ==============================================================================
-- NOTA: Todos los DECLARE al inicio del batch. @predPool como tabla temporal
--       para poder hacer DELETE/INSERT en cada iteración del WHILE.
-- ==============================================================================

-- Tabla temporal para el pool de predicciones de cada proposición
CREATE TABLE #predPool (
    predictionId BIGINT,
    walletId     BIGINT,
    playerId     BIGINT,
    optionCode   NVARCHAR(10),
    wagered      DECIMAL(18,4),
    currencyId   INT
);

DECLARE @validatedProps TABLE (seq INT IDENTITY(1,1), propositionId BIGINT, creatorId BIGINT);
INSERT INTO @validatedProps
    SELECT pm.propositionId, pm.creatorId FROM #PropMap pm
    WHERE pm.statusId = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'validated')
    ORDER BY pm.seqNum;

-- Todas las variables al inicio del batch
DECLARE @valCount        INT          = (SELECT COUNT(1) FROM @validatedProps);
DECLARE @vali            INT          = 1;
DECLARE @vPropId         BIGINT;
DECLARE @vCreatorId      BIGINT;
DECLARE @outcomeCode     NVARCHAR(20);
DECLARE @outcomeId       INT;
DECLARE @winOptCode      NVARCHAR(10);
DECLARE @winOptId        INT;
DECLARE @loseOptId       INT;
DECLARE @outcomeRnd      INT;
DECLARE @ptsPlatformPct  DECIMAL(5,2) = 5.00;
DECLARE @ptsProposerPct  DECIMAL(5,2) = 2.00;
DECLARE @rewardTypeId    INT          = (SELECT transactionTypeId FROM dbo.TransactionTypes WHERE code = 'reward');
DECLARE @refundTypeId    INT          = (SELECT transactionTypeId FROM dbo.TransactionTypes WHERE code = 'refund');
DECLARE @commTypeId      INT          = (SELECT transactionTypeId FROM dbo.TransactionTypes WHERE code = 'commission');
DECLARE @ptsCurrId7      INT          = (SELECT currencyId FROM dbo.Currencies WHERE code = 'PTS');

-- Variables para el bloque de reembolso
DECLARE @rPredId  BIGINT;
DECLARE @rWalId   BIGINT;
DECLARE @rAmt     DECIMAL(18,4);
DECLARE @rBal     DECIMAL(18,4);
DECLARE @rTxId    BIGINT;

-- Variables para distribución normal
DECLARE @totPotPTS   DECIMAL(18,4);
DECLARE @totPotUSD   DECIMAL(18,4);
DECLARE @winPotPTS   DECIMAL(18,4);
DECLARE @winPotUSD   DECIMAL(18,4);
DECLARE @netPTS      DECIMAL(18,4);
DECLARE @netUSD      DECIMAL(18,4);
DECLARE @dPredId     BIGINT;
DECLARE @dWalId      BIGINT;
DECLARE @dOptCode    NVARCHAR(10);
DECLARE @dWag        DECIMAL(18,4);
DECLARE @dCurr       INT;
DECLARE @dEarned     DECIMAL(18,4);
DECLARE @dBalBefore  DECIMAL(18,4);
DECLARE @dTxId       BIGINT;

-- Variables para comisión del creador
DECLARE @creatorPtsWal  BIGINT;
DECLARE @creatorPtsBal  DECIMAL(18,4);
DECLARE @commAmt        DECIMAL(18,4);

WHILE @vali <= @valCount
BEGIN
    SELECT @vPropId = propositionId, @vCreatorId = creatorId
    FROM @validatedProps WHERE seq = @vali;

    -- Distribución de outcomes: 65% yes, 30% no, 3% cancelled, 2% unresolvable
    SET @outcomeRnd = @vali % 100;
    IF @outcomeRnd < 65
    BEGIN SET @outcomeCode = 'yes';          SET @winOptCode = 'yes'; END
    ELSE IF @outcomeRnd < 95
    BEGIN SET @outcomeCode = 'no';           SET @winOptCode = 'no';  END
    ELSE IF @outcomeRnd < 98
    BEGIN SET @outcomeCode = 'cancelled';    SET @winOptCode = NULL;  END
    ELSE
    BEGIN SET @outcomeCode = 'unresolvable'; SET @winOptCode = NULL;  END

    SELECT @outcomeId = outcomeId FROM dbo.PropositionOutcomes WHERE code = @outcomeCode;

    IF NOT EXISTS (SELECT 1 FROM dbo.PropositionOutcomeRecords WHERE propositionId = @vPropId)
    BEGIN
        INSERT INTO dbo.PropositionOutcomeRecords (propositionId, outcomeId, validatedAt, validatedBy)
        VALUES (@vPropId, @outcomeId,
                DATEADD(HOUR, -ABS(CHECKSUM(NEWID())) % 48, GETUTCDATE()), NULL);
    END

    -- Cargar predicciones de esta proposición en la tabla temporal
    DELETE FROM #predPool;
    INSERT INTO #predPool (predictionId, walletId, playerId, optionCode, wagered, currencyId)
        SELECT pr.predictionId, pr.walletId, pr.predictorId, po.code, pr.amountWagered, w.currencyId
        FROM dbo.Predictions pr
        JOIN dbo.PredictionOptions po ON pr.predictionOptionId = po.predictionOptionId
        JOIN dbo.Wallets w ON pr.walletId = w.walletId
        WHERE pr.propositionId = @vPropId
          AND NOT EXISTS (SELECT 1 FROM dbo.PredictionResults WHERE predictionId = pr.predictionId);

    IF @outcomeCode IN ('cancelled', 'unresolvable')
    BEGIN
        DECLARE cur_refund2 CURSOR LOCAL FAST_FORWARD FOR
            SELECT predictionId, walletId, wagered FROM #predPool;
        OPEN cur_refund2;
        FETCH NEXT FROM cur_refund2 INTO @rPredId, @rWalId, @rAmt;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @rBal = balance FROM dbo.Wallets WHERE walletId = @rWalId;

            UPDATE dbo.Wallets
            SET balance = balance + @rAmt, reservedBalance = reservedBalance - @rAmt, updatedAt = GETUTCDATE()
            WHERE walletId = @rWalId;

            INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                          referenceType, referenceId, correlationId, description, createdAt)
            VALUES (@rWalId, @refundTypeId, @rAmt, @rBal, @rBal + @rAmt,
                    'proposition', @vPropId, NEWID(),
                    'Reembolso por proposición cancelada o no resuelta', GETUTCDATE());
            SET @rTxId = SCOPE_IDENTITY();

            INSERT INTO dbo.PredictionResults (predictionId, isWinner, amountEarned, transactionId, resolvedAt)
            VALUES (@rPredId, 0, 0, @rTxId, GETUTCDATE());

            FETCH NEXT FROM cur_refund2 INTO @rPredId, @rWalId, @rAmt;
        END
        CLOSE cur_refund2; DEALLOCATE cur_refund2;
    END
    ELSE
    BEGIN
        SELECT @winOptId  = predictionOptionId FROM dbo.PredictionOptions WHERE code = @winOptCode;
        SELECT @loseOptId = predictionOptionId FROM dbo.PredictionOptions
                            WHERE code = CASE WHEN @winOptCode = 'yes' THEN 'no' ELSE 'yes' END;

        SET @totPotPTS = ISNULL((SELECT SUM(wagered) FROM #predPool WHERE currencyId  = @ptsCurrId7), 0);
        SET @totPotUSD = ISNULL((SELECT SUM(wagered) FROM #predPool WHERE currencyId != @ptsCurrId7), 0);
        SET @winPotPTS = ISNULL((SELECT SUM(wagered) FROM #predPool WHERE optionCode = @winOptCode AND currencyId  = @ptsCurrId7), 0);
        SET @winPotUSD = ISNULL((SELECT SUM(wagered) FROM #predPool WHERE optionCode = @winOptCode AND currencyId != @ptsCurrId7), 0);
        SET @netPTS    = @totPotPTS * (1.0 - (@ptsPlatformPct + @ptsProposerPct) / 100.0);
        SET @netUSD    = @totPotUSD * (1.0 - (@ptsPlatformPct + @ptsProposerPct) / 100.0);

        DECLARE cur_dist CURSOR LOCAL FAST_FORWARD FOR
            SELECT predictionId, walletId, optionCode, wagered, currencyId FROM #predPool;
        OPEN cur_dist;
        FETCH NEXT FROM cur_dist INTO @dPredId, @dWalId, @dOptCode, @dWag, @dCurr;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @dBalBefore = balance FROM dbo.Wallets WHERE walletId = @dWalId;

            IF @dOptCode = @winOptCode
            BEGIN
                IF @dCurr = @ptsCurrId7 AND @winPotPTS > 0
                    SET @dEarned = @dWag + FLOOR(@netPTS * (@dWag / @winPotPTS));
                ELSE IF @dCurr != @ptsCurrId7 AND @winPotUSD > 0
                    SET @dEarned = @dWag + (@netUSD * (@dWag / @winPotUSD));
                ELSE
                    SET @dEarned = @dWag;

                UPDATE dbo.Wallets
                SET balance = balance + @dEarned, reservedBalance = reservedBalance - @dWag, updatedAt = GETUTCDATE()
                WHERE walletId = @dWalId;

                INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                              referenceType, referenceId, correlationId, description, createdAt)
                VALUES (@dWalId, @rewardTypeId, @dEarned, @dBalBefore, @dBalBefore + @dEarned,
                        'proposition', @vPropId, NEWID(), 'Premio por predicción ganadora', GETUTCDATE());
                SET @dTxId = SCOPE_IDENTITY();

                INSERT INTO dbo.RewardDistributions (propositionId, transactionId, distributionTypeId, percentageShare, createdAt)
                VALUES (@vPropId, @dTxId, @rewardTypeId, NULL, GETUTCDATE());

                INSERT INTO dbo.PredictionResults (predictionId, isWinner, amountEarned, transactionId, resolvedAt)
                VALUES (@dPredId, 1, @dEarned, @dTxId, GETUTCDATE());
            END
            ELSE
            BEGIN
                UPDATE dbo.Wallets
                SET reservedBalance = reservedBalance - @dWag, updatedAt = GETUTCDATE()
                WHERE walletId = @dWalId;

                INSERT INTO dbo.PredictionResults (predictionId, isWinner, amountEarned, transactionId, resolvedAt)
                VALUES (@dPredId, 0, 0, NULL, GETUTCDATE());
            END

            FETCH NEXT FROM cur_dist INTO @dPredId, @dWalId, @dOptCode, @dWag, @dCurr;
        END
        CLOSE cur_dist; DEALLOCATE cur_dist;

        -- Comisión del creador en PTS
        IF @totPotPTS > 0
        BEGIN
            SET @commAmt = FLOOR(@totPotPTS * (@ptsProposerPct / 100.0));

            SELECT @creatorPtsWal = walletId, @creatorPtsBal = balance
            FROM dbo.Wallets WHERE playerId = @vCreatorId AND currencyId = @ptsCurrId7;

            IF @creatorPtsWal IS NOT NULL AND @commAmt > 0
            BEGIN
                UPDATE dbo.Wallets SET balance = balance + @commAmt, updatedAt = GETUTCDATE()
                WHERE walletId = @creatorPtsWal;

                INSERT INTO dbo.Transactions (walletId, transactionTypeId, amount, balanceBefore, balanceAfter,
                                              referenceType, referenceId, correlationId, description, createdAt)
                VALUES (@creatorPtsWal, @commTypeId, @commAmt, @creatorPtsBal, @creatorPtsBal + @commAmt,
                        'proposition', @vPropId, NEWID(), 'Comisión del creador de la proposición', GETUTCDATE());
            END
        END
    END

    SET @vali = @vali + 1;
END

IF OBJECT_ID('tempdb..#predPool') IS NOT NULL DROP TABLE #predPool;
PRINT 'PropositionOutcomeRecords y PredictionResults insertados.';
GO

-- ==============================================================================
-- SECCIÓN 8: PaymentMethods y PaymentAttempts para las 5000 proposiciones
-- ==============================================================================
DECLARE @methodTypes TABLE (idx INT IDENTITY(1,1), methodType NVARCHAR(50));
INSERT INTO @methodTypes VALUES ('credit_card'),('debit_card'),('bank_transfer'),('sinpe'),('paypal');
DECLARE @methodCount INT = 5;

DECLARE @depositCurrencies TABLE (idx INT IDENTITY(1,1), currencyId INT);
INSERT INTO @depositCurrencies SELECT currencyId FROM dbo.Currencies WHERE isVirtual = 0;
DECLARE @depCurrCount INT = (SELECT COUNT(1) FROM @depositCurrencies);

DECLARE @playerPayPool TABLE (seq INT IDENTITY(1,1), playerId BIGINT);
INSERT INTO @playerPayPool SELECT TOP 1000 playerId FROM dbo.Players ORDER BY playerId;
DECLARE @payPoolSize INT = (SELECT COUNT(1) FROM @playerPayPool);

DECLARE @pmi INT = 1;
DECLARE @pmPlayerId BIGINT;
DECLARE @pmMethodType NVARCHAR(50);
DECLARE @pmCurrencyId INT;
DECLARE @pmCountryId  INT;
DECLARE @pmMethodId   BIGINT;
DECLARE @pmAmount     DECIMAL(18,4);
DECLARE @pmDepositTypeId INT = (SELECT transactionTypeId FROM dbo.TransactionTypes WHERE code = 'deposit');
DECLARE @pmCorrId     UNIQUEIDENTIFIER;
DECLARE @pmWalletId   BIGINT;
DECLARE @pmBalBefore  DECIMAL(18,4);
DECLARE @pmTxId       BIGINT;

-- Crear un PaymentMethod por cada jugador (1:1 para simplicidad del seeding)
WHILE @pmi <= @payPoolSize
BEGIN
    SELECT @pmPlayerId = playerId FROM @playerPayPool WHERE seq = @pmi;

    IF NOT EXISTS (SELECT 1 FROM dbo.PaymentMethods WHERE playerId = @pmPlayerId)
    BEGIN
        SET @pmMethodType = (SELECT methodType FROM @methodTypes WHERE idx = (@pmi % @methodCount) + 1);
        SET @pmCurrencyId = (SELECT currencyId FROM @depositCurrencies WHERE idx = (@pmi % @depCurrCount) + 1);
        SET @pmCountryId  = (SELECT countryId FROM dbo.Countries WHERE countryId = (@pmi % 10) + 1);

        INSERT INTO dbo.PaymentMethods (playerId, countryId, currencyId, methodType, alias,
                                         accountDetailsEncrypted, isVerified, createdAt)
        VALUES (@pmPlayerId, @pmCountryId, @pmCurrencyId, @pmMethodType,
                CONCAT('Mi ', @pmMethodType, ' #', @pmi),
                CAST(REPLICATE(0x00, 32) AS VARBINARY(MAX)),
                CASE WHEN @pmi % 3 = 0 THEN 1 ELSE 0 END,
                GETUTCDATE());

        SET @pmMethodId = SCOPE_IDENTITY();
    END
    ELSE
        SELECT @pmMethodId = paymentMethodId FROM dbo.PaymentMethods WHERE playerId = @pmPlayerId;

    SET @pmi = @pmi + 1;
END

PRINT 'PaymentMethods insertados.';

-- PaymentAttempts: un registro de pago para cada una de las 5000 proposiciones
-- (simula el depósito de dinero real que permitió apostar en esa proposición)
DECLARE @paProps TABLE (seq INT IDENTITY(1,1), propositionId BIGINT, creatorId BIGINT);
INSERT INTO @paProps SELECT propositionId, creatorId FROM #PropMap ORDER BY seqNum;
DECLARE @paTotalProps INT = (SELECT COUNT(1) FROM @paProps);
DECLARE @pai INT = 1;
DECLARE @paPropId BIGINT;
DECLARE @paCreatorId BIGINT;
DECLARE @paMethodId BIGINT;
DECLARE @paAmount DECIMAL(18,4);
DECLARE @paCurrId INT;
DECLARE @paAttemptType INT = (SELECT transactionTypeId FROM dbo.TransactionTypes WHERE code = 'deposit');
DECLARE @paStatus NVARCHAR(20);

WHILE @pai <= @paTotalProps
BEGIN
    SELECT @paPropId = propositionId, @paCreatorId = creatorId FROM @paProps WHERE seq = @pai;

    SELECT @paMethodId = paymentMethodId FROM dbo.PaymentMethods WHERE playerId = @paCreatorId;
    IF @paMethodId IS NULL
    BEGIN
        SET @pai = @pai + 1;
        CONTINUE;
    END

    SET @paAmount  = CAST(5 + (ABS(CHECKSUM(NEWID())) % 96) AS DECIMAL(18,4));
    SET @paCurrId  = (SELECT currencyId FROM @depositCurrencies WHERE idx = (@pai % @depCurrCount) + 1);
    SET @paStatus  = CASE WHEN @pai % 10 < 8 THEN 'success'
                          WHEN @pai % 10 = 8 THEN 'failed'
                          ELSE 'pending' END;
    SET @pmCorrId  = NEWID();

    INSERT INTO dbo.PaymentAttempts (playerId, paymentMethodId, transactionId, attemptTypeId,
                                     amount, currencyId, status, providerReference,
                                     attemptedAt, resolvedAt)
    VALUES (@paCreatorId, @paMethodId, NULL, @paAttemptType,
            @paAmount, @paCurrId, @paStatus,
            CONCAT('REF-', UPPER(CONVERT(NVARCHAR(36), NEWID()))),
            DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 60, GETUTCDATE()),
            CASE WHEN @paStatus = 'success' THEN DATEADD(MINUTE, 2, GETUTCDATE()) ELSE NULL END);

    SET @pai = @pai + 1;
END

PRINT CONCAT('PaymentAttempts insertados para las ', @paTotalProps, ' proposiciones.');
GO

-- ==============================================================================
-- Limpieza de tablas temporales
-- ==============================================================================
IF OBJECT_ID('tempdb..#PlayerMap') IS NOT NULL DROP TABLE #PlayerMap;
IF OBJECT_ID('tempdb..#PropMap')   IS NOT NULL DROP TABLE #PropMap;
GO

-- ==============================================================================
-- VERIFICACIÓN FINAL DE CONTEOS
-- ==============================================================================
SELECT 'Players'                AS Tabla, COUNT(1) AS Total FROM dbo.Players
UNION ALL SELECT 'Wallets',              COUNT(1) FROM dbo.Wallets
UNION ALL SELECT 'Transactions',         COUNT(1) FROM dbo.Transactions
UNION ALL SELECT 'Propositions',         COUNT(1) FROM dbo.Propositions
UNION ALL SELECT 'PropositionEvents',    COUNT(1) FROM dbo.PropositionEvents
UNION ALL SELECT 'PropositionVotes',     COUNT(1) FROM dbo.PropositionVotes
UNION ALL SELECT 'PropositionOutcomeRecords', COUNT(1) FROM dbo.PropositionOutcomeRecords
UNION ALL SELECT 'Predictions',          COUNT(1) FROM dbo.Predictions
UNION ALL SELECT 'PredictionResults',    COUNT(1) FROM dbo.PredictionResults
UNION ALL SELECT 'RewardDistributions',  COUNT(1) FROM dbo.RewardDistributions
UNION ALL SELECT 'PaymentMethods',       COUNT(1) FROM dbo.PaymentMethods
UNION ALL SELECT 'PaymentAttempts',      COUNT(1) FROM dbo.PaymentAttempts
UNION ALL SELECT 'SocialAccounts',       COUNT(1) FROM dbo.SocialAccounts
ORDER BY Tabla;
GO