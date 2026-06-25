## Problemas por nivel de aislamiento

### READ UNCOMMITTED → Lectura sucia (dirty read)

Deja un cambio sin confirmar y al final lo revierte:
```sql
BEGIN TRANSACTION;
UPDATE dbo.Wallets SET balance = balance + 1000 WHERE walletId = <W1>;
WAITFOR DELAY '00:00:08';
ROLLBACK TRANSACTION; -- se hizo un rollback por lo que este update nunca se debio de ejecutar
```

Ejecuta esto en los primeros 8 segundos, mientras A todavía no confirma nada:
```sql
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT balance FROM dbo.Wallets WHERE walletId = <W1>; -- este select mostrara el 1000 de mas que al final rollbackeamos por lo que muestra un dato erroneo
```

**Problema:** B lee un dato que después se revierte. Si B tomó una decisión basada en ese balance (por ejemplo, autorizar una predicción), esa decisión queda basada en información falsa.

**Cómo mitigarlo:** nunca usar `READ UNCOMMITTED` sobre tablas financieras como `Wallets` o `Transactions`. Usar como mínimo `READ COMMITTED`.

---

### READ COMMITTED → Lectura no repetible (non-repeatable read)


```sql
BEGIN TRANSACTION; -- READ COMMITTED es el nivel por defecto, no hace falta declararlo
SELECT balance FROM dbo.Wallets WHERE walletId = <W1>; -- primera lectura
WAITFOR DELAY '00:00:05';
SELECT balance FROM dbo.Wallets WHERE walletId = <W1>; -- segunda lectura, en la MISMA transacción
COMMIT TRANSACTION;
```

Ejecutá durante los 5 segundos de espera de A:
```sql
UPDATE dbo.Wallets SET balance = balance + 50 WHERE walletId = <W1>;
```

**Problema:** la primera y la segunda lectura de A muestran valores distintos, aunque A nunca tocó esa fila. Esto pasa porque `READ COMMITTED` libera el lock de lectura apenas termina cada `SELECT`.

**Cómo mitigarlo:** Si se necesita leer y volver a leer el mismo dato dentro de una transacción y que no cambie, se tiene que usar`REPEATABLE READ`.

---

### REPEATABLE READ → Lectura fantasma (phantom read)


```sql
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;

SELECT COUNT(*) FROM dbo.Propositions p
JOIN dbo.PropositionStatuses ps ON p.propositionStatusId = ps.propositionStatusId
WHERE ps.code = 'active'; -- primer conteo

WAITFOR DELAY '00:00:05';

SELECT COUNT(*) FROM dbo.Propositions p
JOIN dbo.PropositionStatuses ps ON p.propositionStatusId = ps.propositionStatusId
WHERE ps.code = 'active'; -- segundo conteo, misma transacción

COMMIT TRANSACTION;
```

Durante los 5 segundos, insertá una proposición activa nueva  para la demo lo vamos a hacer directo, sin pasar por todo el flujo de aceptación:
```sql
DECLARE @activeId INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'active');

INSERT INTO dbo.Propositions (creatorId, propositionText, propositionStatusId, predictionsCloseAt, createdAt)
VALUES (<algún playerId existente>, 'Fila fantasma para la demo', @activeId, DATEADD(DAY, 1, GETUTCDATE()), GETUTCDATE());
```

**Problema:** el primer `COUNT(*)` de A da, por ejemplo, 5. El segundo da 6. `REPEATABLE READ` protege las filas que ya se leyeron (no pueden cambiar de valor), pero **no bloquea la inserción de filas nuevas** que entran dentro del mismo criterio de búsqueda.

**Cómo mitigarlo:** si el conteo o el rango necesita ser 100% estable durante toda la transacción , hay que subir a `SERIALIZABLE`.

---

### SERIALIZABLE → Soluciona los anteriores, pero bloquea más

**Sesión A:**
```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;

SELECT COUNT(*) FROM dbo.Propositions p
JOIN dbo.PropositionStatuses ps ON p.propositionStatusId = ps.propositionStatusId
WHERE ps.code = 'active';

WAITFOR DELAY '00:00:08';

SELECT COUNT(*) FROM dbo.Propositions p
JOIN dbo.PropositionStatuses ps ON p.propositionStatusId = ps.propositionStatusId
WHERE ps.code = 'active';

COMMIT TRANSACTION;
```

se ejecuta mientras esta esperando:
```sql
DECLARE @activeId INT = (SELECT propositionStatusId FROM dbo.PropositionStatuses WHERE code = 'active');

INSERT INTO dbo.Propositions (creatorId, propositionText, propositionStatusId, predictionsCloseAt, createdAt)
VALUES (<algún playerId existente>, 'Otra fila para la demo', @activeId, DATEADD(DAY, 1, GETUTCDATE()), GETUTCDATE());
```

La Sesión B se queda esperando(bloqueada) hasta que A haga `COMMIT`. `SERIALIZABLE` toma un lock de rango sobre el criterio `ps.code = 'active'`, así que nadie puede insertar una fila que "encajaría" en ese rango hasta que A termine.

**Problema real de `SERIALIZABLE`:** ya no hay phantom reads ni lecturas inconsistentes, pero a costa de mucho más bloqueo.Si se tienen muchas transacciones concurrentes usando `SERIALIZABLE` sobre las mismas tablas, el riesgo de deadlocks y de transacciones esperando se dispara. Por eso casi nunca se usa `SERIALIZABLE` en toda una transacción completa de una app con muchos usuarios concurrentes (como Gathel); se reserva para operaciones puntuales muy críticas

---