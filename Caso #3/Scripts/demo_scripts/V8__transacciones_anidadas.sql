CREATE OR ALTER PROCEDURE demo.usp_Demo_OnboardAndPropose
    @username    NVARCHAR(50),
    @email       NVARCHAR(255),
    @forzarFallo BIT = 0          
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hash VARBINARY(64) = HASHBYTES('SHA2_256', 'demo123');
    DECLARE @salt VARBINARY(64) = HASHBYTES('SHA2_256', 'saltdemo');
    
    DECLARE @newPlayerId BIGINT, @newPropositionId BIGINT, @creatorIdUsado BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;  
        PRINT 'NIVEL 1 abierto. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);

        EXEC dbo.usp_RegisterPlayer
            @username = @username, 
            @email = @email,
            @passwordHash = @hash,
            @passwordSalt = @salt,
            @newPlayerId = @newPlayerId OUTPUT;

        PRINT 'NIVEL 2 OK. playerId = ' + CAST(@newPlayerId AS VARCHAR);

        SET @creatorIdUsado = CASE WHEN @forzarFallo = 1 THEN 999999999 ELSE @newPlayerId END;

        EXEC dbo.usp_CreateProposition
            @creatorId = @creatorIdUsado,
            @propositionText = 'Proposición de prueba - demo transacciones anidadas',
            @newPropositionId = @newPropositionId OUTPUT;

        PRINT 'NIVEL 3 OK. propositionId = ' + CAST(@newPropositionId AS VARCHAR);

        COMMIT TRANSACTION;  
        PRINT '>>> COMMIT exitoso. Jugador y proposición quedaron guardados.';
    END TRY
    BEGIN CATCH
        PRINT '>>> ERROR: ' + ERROR_MESSAGE();
        PRINT '>>> XACT_STATE() = ' + CAST(XACT_STATE() AS VARCHAR) + ' (-1 = transacción condenada, debe revertirse)';

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        PRINT '>>> ROLLBACK aplicado. NADA de lo anterior quedó guardado (ni el jugador del nivel 2).';
    END CATCH
END;
GO