-- =====================================================================================
-- SECCIÓN 1 — ROLES DE BASE DE DATOS CON PERMISOS ESPECÍFICOS
-- =====================================================================================

CREATE ROLE rol_soporte_lectura AUTHORIZATION dbo; -- Soporte al cliente: solo lectura
GO
CREATE ROLE rol_moderacion AUTHORIZATION dbo; -- Moderacion: puede sancionar cuentas (escritura puntual)
GO
CREATE ROLE rol_finanzas AUTHORIZATION dbo; -- Finanzas: control total sobre wallets/transacciones
GO
CREATE ROLE rol_auditoria AUTHORIZATION dbo; -- Auditoria/cumplimiento: solo acceso indirecto vía SP/Function
GO

-- Permisos base de cada rol
-- Notese el permiso a nivel de COLUMNA en Players: el soporte nunca necesita ver
-- passwordHash ni passwordSalt, así que ni siquiera se le concede el permiso sobre esas columnas 
GRANT SELECT ON dbo.Players (playerId, username, email, playerStatusId, countryId, isVerified, createdAt)
    TO rol_soporte_lectura;
GRANT SELECT ON dbo.Wallets TO rol_soporte_lectura;
GO

-- Moderacion solo puede cambiar el estado del jugador (ej. suspender/banear), nada más
GRANT UPDATE ON dbo.Players (playerStatusId) TO rol_moderacion;
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Wallets TO rol_finanzas;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Transactions TO rol_finanzas;
GO

-- rol_auditoria NO recibe ningún permiso directo sobre tablas: solo podra acceder
-- a los datos de forma indirecta mediante el Stored Procedure / Function


-- =====================================================================================
-- LOGINS Y USUARIOS DE PRUEBA + ASIGNACIÓN A ROLES
-- =====================================================================================

CREATE LOGIN login_soporte  WITH PASSWORD = 'Soporte#2026!',    CHECK_POLICY = ON;
CREATE LOGIN login_moderador WITH PASSWORD = 'Moderador#2026!',  CHECK_POLICY = ON;
CREATE LOGIN login_finanzas WITH PASSWORD = 'Finanzas#2026!',   CHECK_POLICY = ON;
CREATE LOGIN login_auditor  WITH PASSWORD = 'Auditor#2026!',    CHECK_POLICY = ON;
CREATE LOGIN login_directo  WITH PASSWORD = 'Directo#2026!',    CHECK_POLICY = ON;
CREATE LOGIN login_player1  WITH PASSWORD = 'Player1#2026!',    CHECK_POLICY = ON;
CREATE LOGIN login_player2  WITH PASSWORD = 'Player2#2026!',    CHECK_POLICY = ON;
GO

CREATE USER usr_soporte FOR LOGIN login_soporte;
CREATE USER usr_moderador FOR LOGIN login_moderador;
CREATE USER usr_finanzas FOR LOGIN login_finanzas;
CREATE USER usr_auditor FOR LOGIN login_auditor;
CREATE USER usr_directo FOR LOGIN login_directo;
CREATE USER usr_player1 FOR LOGIN login_player1;
CREATE USER usr_player2 FOR LOGIN login_player2;
GO

-- Asignación de usuarios a roles (permisos HEREDADOS)
ALTER ROLE rol_soporte_lectura ADD MEMBER usr_soporte;
ALTER ROLE rol_moderacion ADD MEMBER usr_moderador;
ALTER ROLE rol_finanzas ADD MEMBER usr_finanzas;
ALTER ROLE rol_auditoria ADD MEMBER usr_auditor;
GO

-- usr_directo NO se asigna a ningún rol: solo tendrá permisos directos
-- usr_player1 / usr_player2 representan jugadores autenticados (no staff): solo
-- tendrán permisos DIRECTOS de lectura sobre su propia información 


-- =====================================================================================
-- PERMISOS DIRECTOS Y DENEGACIONES
-- Demuestra: permiso directo + permiso heredado en un mismo usuario, y lectura sin escritura (o viceversa) sobre la misma tabla
-- =====================================================================================

-- usr_soporte: ya tiene SELECT HEREDADO (vía rol_soporte_lectura) sobre Players/Wallets.
-- Se le agrega un permiso DIRECTO adicional, no relacionado con el rol, para investigar sesiones sospechosas:
GRANT SELECT ON dbo.PlayerSessions TO usr_soporte;

-- Se refuerza que usr_soporte NO puede escribir en Players (solo lectura)
DENY INSERT, UPDATE, DELETE ON dbo.Players TO usr_soporte;
GO

-- usr_moderador: tiene UPDATE heredado (solo playerStatusId), pero NO lectura
DENY SELECT ON dbo.Players TO usr_moderador;
GO

-- usr_auditor: sin permisos directos sobre las tablas. Se deniega explícitamente el
-- SELECT directo para forzar el acceso INDIRECTO vía SP/Function
DENY SELECT ON dbo.Players TO usr_auditor;
DENY SELECT ON dbo.Transactions TO usr_auditor;
GO

-- usr_directo: permiso 100% DIRECTO, sin pertenecer a ningún rol
GRANT SELECT ON dbo.Players (playerId, username, playerStatusId) TO usr_directo;
GO

-- usr_player1 / usr_player2: acceso directo de lectura (no son staff, no usan roles
-- administrativos). El alcance de filas correcto lo impone el RLS
GRANT SELECT ON dbo.Players TO usr_player1;
GRANT SELECT ON dbo.Wallets TO usr_player1;
GRANT SELECT ON dbo.Players TO usr_player2;
GRANT SELECT ON dbo.Wallets TO usr_player2;
GO


-- =====================================================================================
-- STORED PROCEDURE Y FUNCTION PARA ACCESO INDIRECTO
-- (ownership chaining / cadena de propiedad)
-- =====================================================================================

CREATE PROCEDURE dbo.sp_ConsultarResumenJugadores
AS
BEGIN
    SET NOCOUNT ON;
    SELECT playerId, username, email, playerStatusId, createdAt
    FROM dbo.Players;
END
GO

CREATE FUNCTION dbo.fn_TransaccionesPorJugador(@playerId BIGINT)
RETURNS TABLE
AS
RETURN
(
    SELECT t.transactionId, t.transactionTypeId, t.amount, t.balanceBefore, t.balanceAfter, t.createdAt
    FROM dbo.Transactions t
    INNER JOIN dbo.Wallets w ON w.walletId = t.walletId
    WHERE w.playerId = @playerId
);
GO

-- Solo se otorga permiso de EJECUCIÓN/CONSULTA, nunca SELECT directo sobre las tablas.
-- Como el SP/Function y las tablas pertenecen al mismo propietario (dbo), SQL Server no revalida permisos sobre Players/Transactions al ejecutarlos (ownership chaining):
-- basta con EXECUTE (en el SP) o SELECT (en la Function, que es como se invoca un TVF).
GRANT EXECUTE ON dbo.sp_ConsultarResumenJugadores TO rol_auditoria;
GRANT SELECT  ON dbo.fn_TransaccionesPorJugador TO rol_auditoria;
GO


-- =====================================================================================
-- DYNAMIC DATA MASKING SOBRE CAMPOS SENSIBLES
-- =====================================================================================

ALTER TABLE dbo.Players
    ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');
GO

ALTER TABLE dbo.Players
    ALTER COLUMN username ADD MASKED WITH (FUNCTION = 'partial(2,"XXXXX",0)');
GO

ALTER TABLE dbo.Players
    ALTER COLUMN passwordHash ADD MASKED WITH (FUNCTION = 'default()');
GO

ALTER TABLE dbo.Wallets
    ALTER COLUMN balance ADD MASKED WITH (FUNCTION = 'random(1, 500)');
GO

-- Solo Finanzas ve los datos reales (sin enmascarar) en las columnas anteriores
GRANT UNMASK TO rol_finanzas;
GO

-- GRANT UNMASK ON dbo.Wallets(balance) TO <usuario>; para otorgar UNMASK
-- columna por columna en lugar de a nivel de toda la base de datos.


-- =====================================================================================
-- MASTER KEY + CERTIFICADO + LLAVE SIMÉTRICA
-- Base para el cifrado de datos sensibles recuperables
-- =====================================================================================

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'M@sterKey_Gathel_2026!';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'CertCifradoGathel')
BEGIN
    CREATE CERTIFICATE CertCifradoGathel
        WITH SUBJECT = 'Certificado para cifrado de datos sensibles - GathelDB';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'SimKeyGathel')
BEGIN
    CREATE SYMMETRIC KEY SimKeyGathel
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE CertCifradoGathel;
END
GO

-- Ejemplo de uso real del cifrado por certificado sobre una columna que ya estaba
-- diseñada para contener datos cifrados (PaymentMethods.accountDetailsEncrypted)
OPEN SYMMETRIC KEY SimKeyGathel
    DECRYPTION BY CERTIFICATE CertCifradoGathel;

INSERT INTO dbo.PaymentMethods (playerId, countryId, currencyId, methodType, alias, accountDetailsEncrypted, isVerified)
SELECT p.playerId, NULL, NULL, 'bank_transfer', 'Cuenta de prueba',
       ENCRYPTBYKEY(KEY_GUID('SimKeyGathel'), N'IBAN: CR00-0000-0000-0000-0000-00'),
       1
FROM dbo.Players p
WHERE p.username = 'usr_player1';

CLOSE SYMMETRIC KEY SimKeyGathel;
GO


-- =====================================================================================
-- ROW-LEVEL SECURITY BASADA EN EL USUARIO AUTENTICADO
-- =====================================================================================

CREATE SCHEMA Security;
GO

-- Un jugador solo ve su propia fila en Players. El personal (soporte, finanzas,auditoría) y dbo ven todas las filas.
CREATE FUNCTION Security.fn_PredicadoJugadores(@username NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_resultado
    WHERE @username = USER_NAME()
       OR IS_MEMBER('rol_finanzas') = 1
       OR IS_MEMBER('rol_soporte_lectura') = 1
       OR IS_MEMBER('rol_auditoria') = 1
       OR USER_NAME() = 'dbo';
GO

-- Un jugador solo ve su propia wallet (vía Players.username). Mismo criterio de excepción para el personal.
CREATE FUNCTION Security.fn_PredicadoWallets(@playerId BIGINT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_resultado
    WHERE EXISTS (
              SELECT 1 FROM dbo.Players p
              WHERE p.playerId = @playerId AND p.username = USER_NAME()
          )
       OR IS_MEMBER('rol_finanzas') = 1
       OR IS_MEMBER('rol_soporte_lectura') = 1
       OR USER_NAME() = 'dbo';
GO

CREATE SECURITY POLICY Security.PoliticaJugadores
    ADD FILTER PREDICATE Security.fn_PredicadoJugadores(username) ON dbo.Players,
    ADD FILTER PREDICATE Security.fn_PredicadoWallets(playerId) ON dbo.Wallets,
    ADD BLOCK PREDICATE Security.fn_PredicadoWallets(playerId) ON dbo.Wallets AFTER INSERT,
    ADD BLOCK PREDICATE Security.fn_PredicadoWallets(playerId) ON dbo.Wallets AFTER UPDATE
WITH (STATE = ON);
GO

-- Resultado esperado:
--   * usr_player1 solo ve su propia fila en Players y su propia wallet.
--   * usr_player2 solo ve su propia fila en Players y su propia wallet.
--   * usr_soporte, usr_finanzas y usr_auditor (vía sus roles) ven todas las filas.
--   * Ningún jugador puede insertar/actualizar una wallet asignándole un playerId
--     que no sea el suyo (bloqueado por el BLOCK PREDICATE).


-- =====================================================================================
-- CIFRADO DE CONTRASEÑAS CON MASTER CERTIFICATE (DEMOSTRACIÓN EXPLÍCITA)
--
-- Nota de diseño: Players.passwordHash es, correctamente, un HASH irreversible
-- (no se debe descifrar una contraseña real, solo verificarla). El cifrado
-- reversible con certificado se demuestra aquí de forma explícita sobre un valor
-- de contraseña de ejemplo, y se aplica en la práctica a datos que SÍ deben ser
-- recuperables, como PaymentMethods.accountDetailsEncrypted.
-- =====================================================================================

OPEN SYMMETRIC KEY SimKeyGathel
    DECRYPTION BY CERTIFICATE CertCifradoGathel;

DECLARE @PasswordPlano NVARCHAR(100) = N'ContrasenaDemo#2026!';
DECLARE @PasswordCifrada VARBINARY(256) = ENCRYPTBYKEY(KEY_GUID('SimKeyGathel'), @PasswordPlano);

SELECT
    @PasswordPlano AS PasswordOriginal,
    @PasswordCifrada AS PasswordCifradaBinaria,
    CONVERT(NVARCHAR(100), DECRYPTBYKEY(@PasswordCifrada)) AS PasswordDescifradaVerificacion;

CLOSE SYMMETRIC KEY SimKeyGathel;
GO
