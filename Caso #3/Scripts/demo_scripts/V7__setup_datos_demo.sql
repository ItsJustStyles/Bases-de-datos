CREATE SCHEMA demo;
GO

DECLARE @hash1 VARBINARY(64) = HASHBYTES('SHA2_256','demo123');
DECLARE @salt1 VARBINARY(64) = HASHBYTES('SHA2_256','salt1');
DECLARE @p1 BIGINT;

IF NOT EXISTS (SELECT 1 FROM dbo.Players WHERE username = 'demo_player1')
BEGIN
    EXEC dbo.usp_RegisterPlayer
        @username = 'demo_player1', @email = 'demo1@gathel.test',
        @passwordHash = @hash1, @passwordSalt = @salt1,
        @newPlayerId = @p1 OUTPUT;
    PRINT 'Jugador 1 creado.';
END

DECLARE @hash2 VARBINARY(64) = HASHBYTES('SHA2_256','demo123');
DECLARE @salt2 VARBINARY(64) = HASHBYTES('SHA2_256','salt2');
DECLARE @p2 BIGINT;

IF NOT EXISTS (SELECT 1 FROM dbo.Players WHERE username = 'demo_player2')
BEGIN
    EXEC dbo.usp_RegisterPlayer
        @username = 'demo_player2', @email = 'demo2@gathel.test',
        @passwordHash = @hash2, @passwordSalt = @salt2,
        @newPlayerId = @p2 OUTPUT;
    PRINT 'Jugador 2 creado.';
END

DECLARE @hash3 VARBINARY(64) = HASHBYTES('SHA2_256','demo123');
DECLARE @salt3 VARBINARY(64) = HASHBYTES('SHA2_256','salt3');
DECLARE @p3 BIGINT;

IF NOT EXISTS (SELECT 1 FROM dbo.Players WHERE username = 'demo_player3')
BEGIN
    EXEC dbo.usp_RegisterPlayer
        @username = 'demo_player3', @email = 'demo3@gathel.test',
        @passwordHash = @hash3, @passwordSalt = @salt3,
        @newPlayerId = @p3 OUTPUT;
    PRINT 'Jugador 3 creado.';
END
GO