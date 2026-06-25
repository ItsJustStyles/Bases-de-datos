CREATE OR ALTER PROCEDURE demo.usp_Demo_DeadlockWrite_A
    @walletId1 BIGINT, @walletId2 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    UPDATE dbo.Wallets SET balance = balance + 1, updatedAt = GETUTCDATE() WHERE walletId = @walletId1;
    PRINT 'Sesión A: actualizó wallet ' + CAST(@walletId1 AS VARCHAR) + '. Esperando 5s...';
    WAITFOR DELAY '00:00:05';

    UPDATE dbo.Wallets SET balance = balance + 1, updatedAt = GETUTCDATE() WHERE walletId = @walletId2;
    PRINT 'Sesión A: actualizó wallet ' + CAST(@walletId2 AS VARCHAR);

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE demo.usp_Demo_DeadlockWrite_B
    @walletId1 BIGINT, @walletId2 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    UPDATE dbo.Wallets SET balance = balance + 1, updatedAt = GETUTCDATE() WHERE walletId = @walletId2;
    PRINT 'Sesión B: actualizó wallet ' + CAST(@walletId2 AS VARCHAR) + '. Esperando 5s...';
    WAITFOR DELAY '00:00:05';

    UPDATE dbo.Wallets SET balance = balance + 1, updatedAt = GETUTCDATE() WHERE walletId = @walletId1;
    PRINT 'Sesión B: actualizó wallet ' + CAST(@walletId1 AS VARCHAR);

    COMMIT TRANSACTION;
END;
GO