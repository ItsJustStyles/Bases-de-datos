CREATE OR ALTER PROCEDURE demo.usp_Demo_DeadlockCiclico_T1
    @walletR1 BIGINT, @walletR2 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    UPDATE dbo.Wallets SET balance = balance + 1 WHERE walletId = @walletR1;
    PRINT 'T1: tomó R1, esperando...';
    WAITFOR DELAY '00:00:10';
    UPDATE dbo.Wallets SET balance = balance + 1 WHERE walletId = @walletR2; -- pide R2 (lo tiene T2)
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE demo.usp_Demo_DeadlockCiclico_T2
    @walletR2 BIGINT, @walletR3 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    UPDATE dbo.Wallets SET balance = balance + 1 WHERE walletId = @walletR2;
    PRINT 'T2: tomó R2, esperando...';
    WAITFOR DELAY '00:00:10';
    UPDATE dbo.Wallets SET balance = balance + 1 WHERE walletId = @walletR3; -- pide R3 (lo tiene T3)
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE demo.usp_Demo_DeadlockCiclico_T3
    @walletR3 BIGINT, @walletR1 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    UPDATE dbo.Wallets SET balance = balance + 1 WHERE walletId = @walletR3;
    PRINT 'T3: tomó R3, esperando...';
    WAITFOR DELAY '00:00:10';
    UPDATE dbo.Wallets SET balance = balance + 1 WHERE walletId = @walletR1; -- pide R1 (lo tiene T1) -> cierra el ciclo
    COMMIT TRANSACTION;
END;
GO