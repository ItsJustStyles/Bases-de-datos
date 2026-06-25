# Flyway en SQL Server — Gathel

Documentación del funcionamiento, configuración y hallazgos obtenidos al usar **Flyway** como herramienta de versionamiento de base de datos para el proyecto **Gathel**, sobre **SQL Server**.

> Este documento complementa el `README.md` del repositorio. Las migraciones reales del proyecto (`V1` a `V11`) viven en `/src/db/migrations` (o la ruta equivalente que defina el equipo) y se referencian a lo largo de este documento como ejemplo concreto de cada concepto.

---

## 1. ¿Qué es Flyway y por qué se usa en Gathel?

Flyway es una herramienta de migración de bases de datos basada en archivos `.sql` versionados. Su filosofía es simple: cada cambio de esquema (tabla, índice, stored procedure, rol, dato semilla, etc.) se escribe en un archivo con un número de versión, se confirma al repositorio, y Flyway se encarga de aplicar **en orden** y **una sola vez** cada migración pendiente sobre la base de datos destino.

En Gathel se usa para garantizar que:

- Todo el equipo (y el ambiente de CI/CD y el MVP en Docker) tenga exactamente la misma estructura y datos iniciales.
- Cada cambio de esquema, stored procedure, rol de seguridad, índice o script de demostración quede versionado y trazable en Git, en lugar de aplicarse "a mano" sobre la base de datos de cada desarrollador.
- Existan comandos para verificar el estado real de la base de datos (`info`, `validate`) sin depender de la memoria del equipo.

---

## 2. Instalación

Existen varias formas de instalar Flyway; el equipo evaluó las tres siguientes.

### 2.1 Flyway CLI (línea de comandos, opción usada por el equipo)

1. Descargar el binario desde el sitio oficial (`flywaydb.org` / Redgate) según el sistema operativo (Windows, macOS, Linux).
2. Descomprimir el `.zip`/`.tar.gz` en una carpeta, por ejemplo `C:\flyway` o `~/flyway`.
3. Agregar la carpeta `bin` (o la raíz, según el empaquetado) al `PATH` del sistema.
4. Verificar la instalación:

   ```bash
   flyway -v
   ```

El driver JDBC de SQL Server (`mssql-jdbc`) viene **incluido** en la distribución de línea de comandos desde hace varias versiones, así que no fue necesario descargarlo ni configurarlo aparte — a diferencia de motores menos comunes, donde sí hay que añadir el driver manualmente a la carpeta `drivers`.

### 2.2 Vía Docker

Alternativa usada para probar migraciones sin instalar nada en el sistema operativo anfitrión (útil porque el MVP corre contenerizado con `docker-compose`):

```bash
docker run --rm -v "$(pwd)/migrations:/flyway/sql" \
  -v "$(pwd)/flyway.toml:/flyway/conf/flyway.toml" \
  redgate/flyway migrate
```

Esta opción es la recomendada si SQL Server también corre en contenedor, ya que Flyway puede ejecutarse en la misma red de Docker Compose (`flyway` como un servicio adicional que depende de `sqlserver`).

### 2.3 Vía plugin de build (Maven/Gradle)

No se usó en Gathel porque el backend del MVP no es Java, pero se documenta como alternativa: Flyway ofrece plugins oficiales de Maven y Gradle que ejecutan `migrate` automáticamente como parte del build. Se descartó porque el equipo prefirió mantener Flyway como un paso explícito e independiente del lenguaje del backend.

**Decisión final del equipo:** CLI standalone para desarrollo local + el mismo binario invocado dentro de un contenedor efímero en `docker-compose` para levantar el ambiente completo de un solo comando.

---

## 3. Configuración

### 3.1 Archivo de configuración: `flyway.toml`

Las versiones recientes de Flyway reemplazaron el antiguo `flyway.conf` por un archivo `flyway.toml`, con secciones más legibles y soporte para múltiples ambientes (`environments`). Esta es la configuración base usada en el proyecto:

```toml
[flyway]
locations = ["filesystem:./migrations"]
schemas = ["dbo", "demo", "Security"]
baselineOnMigrate = true
baselineVersion = "0"
encoding = "UTF-8"
mixed = true            # permite mezclar statements transaccionales y no transaccionales en un mismo script
cleanDisabled = true    # evita borrados accidentales de la BD del equipo

[environments.default]
url = "jdbc:sqlserver://localhost:1433;databaseName=GathelDB;encrypt=true;trustServerCertificate=true"
user = "flyway_admin"
password = "${FLYWAY_PASSWORD}"   # se inyecta por variable de entorno, nunca se commitea
```

Puntos relevantes de la configuración:

- **`locations`**: ruta donde Flyway busca los archivos `V*.sql`. Puede haber varias rutas (por ejemplo, separar `migrations/` de `seeds/`), pero el equipo decidió mantener una sola carpeta para simplificar el orden de versionado.
- **`schemas`**: Flyway crea automáticamente la tabla de historial (`flyway_schema_history`) en el primer esquema de la lista (`dbo`) y valida que los demás esquemas usados por las migraciones (`demo`, `Security`, creados en `V7` y `V4` respectivamente) existan o sean creados por las propias migraciones.
- **`mixed = true`**: necesario porque algunas migraciones (`V4`) combinan instrucciones DDL de seguridad (`CREATE LOGIN`, `CREATE MASTER KEY`) con instrucciones que SQL Server no permite dentro de una transacción explícita abierta por Flyway.
- **`cleanDisabled = true`**: medida de seguridad. El comando `flyway clean` borra **todos** los objetos de los esquemas configurados; se desactivó para que nadie lo ejecute por error contra la base de datos compartida del equipo.
- **Contraseña por variable de entorno**: ninguna credencial real se versiona en Git. Cada integrante define `FLYWAY_PASSWORD` (y el usuario, si aplica) en su propio `.env` o en las variables de entorno de su sistema.

### 3.2 Cadena de conexión a SQL Server

Dos parámetros de la URL JDBC fueron necesarios específicamente por usar SQL Server en un contenedor local sin certificado válido:

- `encrypt=true`
- `trustServerCertificate=true`

Sin `trustServerCertificate=true`, la conexión falla con un error de validación SSL/TLS porque el certificado autogenerado de la instancia local de SQL Server no es de confianza para el cliente JDBC por defecto.

### 3.3 Usuario de Flyway vs. usuarios de la aplicación

El usuario con el que Flyway se conecta (`flyway_admin` en el ejemplo) necesita permisos amplios: `db_owner` o, como mínimo, permisos para crear tablas, roles, logins, certificados y llaves (porque `V4` crea `LOGIN`s, `MASTER KEY`, certificados y llaves simétricas a nivel de servidor/base de datos). Este usuario **no** es el mismo que los usuarios de aplicación (`usr_player1`, `usr_finanzas`, etc.) creados *por* las migraciones — esos se crean y se usan únicamente para el laboratorio de seguridad, nunca para correr Flyway.

---

## 4. Estructura de carpetas

Estructura adoptada en el repositorio para el módulo de base de datos del proyecto:

```
Scripts/                     
├── V1__init_gathel.sql              
├── V2__stored_procedures_gathel.sql 
├── V3__seeding_gathel.sql           
├── V4__seguridad_gathel.sql         
├── V5__indices_gathel.sql           
├── V6__indices_para_optimizar_ordenamiento_y_filtrado.sql
└── demo_scripts/
    ├── V7__setup_datos_demo.sql
    ├── V8__transacciones_anidadas.sql
    ├── V9__deadlock_escritura_escritura.sql
    ├── V10__deadlock_select_escritura.sql
    └── V11__deadlock_ciclico.sql
```

Cada archivo corresponde a una responsabilidad única, lo que facilita revisarlos en Pull Requests independientes:

| Migración | Propósito |
|---|---|
| `V1__init_gathel.sql` | Esquema base: tablas, relaciones, restricciones del modelo de datos de Gathel. |
| `V2__stored_procedures_gathel.sql` | Stored Procedures y Functions de negocio (`usp_RegisterPlayer`, `usp_CreateProposition`, etc.). |
| `V3__seeding_gathel.sql` | Seeding inicial/estructura para datos masivos (jugadores, proposiciones, eventos, pagos). |
| `V4__seguridad_gathel.sql` | Roles, logins, usuarios, permisos directos/heredados, masking, cifrado y RLS (Security Lab). |
| `V5__indices_gathel.sql` | Índices sobre llaves foráneas y columnas de búsqueda frecuente. |
| `V6__indices_para_optimizar_ordenamiento_y_filtrado.sql` | Índices adicionales orientados a `ORDER BY`/filtrado en listados (proposiciones, transacciones). |
| `V7__setup_datos_demo.sql` | Esquema `demo` y jugadores de demostración usados por las pruebas de transacciones/deadlocks. |
| `V8__transacciones_anidadas.sql` | SP de demostración de transacciones anidadas (caso exitoso y caso con `ROLLBACK`). |
| `V9__deadlock_escritura_escritura.sql` | Demostración de deadlock escritura-escritura. |
| `V10__deadlock_select_escritura.sql` | Demostración de deadlock lectura (`SELECT`) vs. escritura. |
| `V11__deadlock_ciclico.sql` | Demostración de deadlock cíclico de 3 transacciones (T1→T2→T3→T1). |

---

## 5. Versionamiento

Flyway ordena y aplica las migraciones según una convención de nombres estricta:

```
V<versión>__<descripción>.sql
```

- **`V`**: prefijo obligatorio para migraciones *versionadas* (forward-only). Existe también el prefijo `R` para migraciones *repetibles* (se re-ejecutan cada vez que cambia su contenido, útiles para vistas o procedimientos que se quieren mantener siempre actualizados) y `U` para migraciones de *undo* — no usado en este proyecto (ver sección 7).
- **`<versión>`**: número entero o con puntos/guiones bajos (`1`, `1.1`, `1_1`, `2`...). Determina el **orden de ejecución**, no el orden alfabético del nombre completo. En Gathel se usó numeración entera simple y secuencial (`V1` … `V11`).
- **Doble guión bajo `__`**: separador obligatorio entre versión y descripción.
- **`<descripción>`**: texto libre, usado solo para humanos (aparece en `flyway info` y en la tabla de historial); Flyway lo ignora para efectos de orden.

### 5.1 Inmutabilidad

Una vez que una migración fue aplicada en cualquier ambiente compartido (la base de datos de otro integrante, CI, o la base de "verdad" del equipo), **no se modifica su contenido**. Flyway calcula un *checksum* (CRC32) del contenido de cada script y lo guarda en `flyway_schema_history`; si alguien edita un archivo ya aplicado, el checksum calculado al correr `flyway migrate`/`flyway validate` no coincide con el guardado y Flyway **detiene la ejecución** con un error de validación, para evitar que distintos ambientes terminen con el mismo número de versión pero contenido distinto.

Si un cambio es necesario después de aplicado, la solución correcta es crear una **nueva** migración (`V12__...sql`) que corrija o transforme lo que dejó la anterior — nunca editar `V5`, por ejemplo, después de que ya corrió en la base de un compañero.

### 5.2 Migraciones repetibles (no usadas, pero evaluadas)

El equipo consideró usar `R__` para las vistas o para `Security.fn_PredicadoJugadores`/`Security.fn_PredicadoWallets`, ya que técnicamente podrían cambiar de definición sin alterar el "número de versión" del esquema. Se descartó para mantener **todo** bajo el mismo esquema de versionado secuencial y facilitar la trazabilidad pedida por el caso (todo administrado y versionado por Flyway y Git, en orden).

---

## 6. Ejecución de migraciones

### 6.1 Comandos principales usados

```bash
# Ver el estado actual: qué migraciones existen, cuáles están aplicadas, pendientes o con error
flyway info

# Aplicar todas las migraciones pendientes, en orden, una transacción por script (cuando es posible)
flyway migrate

# Verificar que los checksums de las migraciones aplicadas coincidan con los archivos locales
flyway validate

# Marcar una base de datos preexistente como "ya en la versión X", sin volver a correr V1..VX
flyway baseline -baselineVersion=4

# Reparar la tabla de historial tras una migración fallida o editada manualmente (alinea checksums)
flyway repair
```

### 6.2 Flujo real en el proyecto

1. Un integrante crea/levanta una instancia limpia de SQL Server (nativa o vía Docker).
2. Corre `flyway migrate` apuntando a esa instancia.
3. Flyway crea automáticamente la tabla `flyway_schema_history` (si no existe) y aplica, en orden, `V1` → `V11`.
4. Cada fila insertada en `flyway_schema_history` queda con: número de versión, descripción, tipo (`SQL`), checksum, usuario que instaló, fecha, tiempo de ejecución y si tuvo éxito (`success = 1`).
5. Si alguien agrega `V12__...sql` más adelante, solo esa migración se aplica al correr `flyway migrate` de nuevo — las anteriores se omiten porque ya están registradas como exitosas.

Ejemplo simplificado de cómo se ve `flyway_schema_history` después de aplicar las once migraciones:

| installed_rank | version | description | type | success |
|---|---|---|---|---|
| 1 | 1 | init gathel | SQL | true |
| 2 | 2 | stored procedures gathel | SQL | true |
| ... | ... | ... | ... | ... |
| 11 | 11 | deadlock ciclico | SQL | true |

### 6.3 Manejo de `GO` (lotes de T-SQL)

Un hallazgo central (ver sección 8) es que Flyway **entiende nativamente** el separador de lotes `GO` de SQL Server: el motor de parseo específico de SQL Server divide cada migración en *batches* exactamente como lo haría `sqlcmd` o SSMS. Esto permitió pegar scripts T-SQL "tal cual" (incluyendo `CREATE PROCEDURE ... GO`, `CREATE FUNCTION ... GO`) sin tener que reescribirlos para una herramienta de migración genérica.

---

## 7. Rollback

### 7.1 Limitación encontrada: `Undo` es una funcionalidad de pago

Flyway divide sus comandos en **Migrate, Info, Validate, Baseline, Repair, Clean** (disponibles en la edición Community/gratuita) y **Undo** (disponible solo en las ediciones Teams/Enterprise, mediante licencia). El comando `undo` busca un archivo `U<versión>__descripcion.sql` que revierte exactamente lo que hizo su `V` correspondiente. Como Gathel usa la edición Community (gratuita, apropiada para un proyecto académico), **no se cuenta con rollback automático nativo**.

### 7.2 Estrategia de rollback adoptada en el proyecto

Ante esta limitación, el equipo adoptó una estrategia **forward-only**, estándar en proyectos que usan Flyway Community:

- **Migraciones compensatorias**: si una migración introduce un error o un diseño que se quiere revertir, se escribe una **nueva** migración (`V12`, `V13`, ...) que deshace el cambio (por ejemplo, un `DROP INDEX` para revertir un índice creado en `V6`, o un `ALTER TABLE ... DROP COLUMN MASKED` para revertir un masking de `V4`). Nunca se edita ni se borra la migración original.
- **Bases de datos descartables para pruebas**: gracias a que SQL Server corre en un contenedor Docker, "revertir" durante el desarrollo local casi siempre significó **destruir el contenedor y volver a crear la base desde cero** corriendo `flyway migrate` de nuevo sobre una instancia limpia, en lugar de intentar un rollback parcial.
- **Backups previos a migraciones riesgosas**: antes de aplicar migraciones que tocan seguridad o cifrado (`V4`) sobre una base con datos reales (no descartable), se documentó como buena práctica tomar un backup completo (`BACKUP DATABASE`) y, en caso de fallo, restaurarlo en lugar de intentar revertir manualmente roles, certificados y llaves.

Esta estrategia es consistente con la recomendación oficial de Flyway para usuarios de la edición gratuita: tratar las migraciones como un log de cambios append-only, y resolver errores "hacia adelante".

---

## 8. Hallazgos relevantes obtenidos durante las pruebas

1. **`GO` funciona sin configuración adicional.** A diferencia de herramientas de migración agnósticas al motor, Flyway con el dialecto de SQL Server reconoce `GO` como separador de lotes de forma nativa. Esto fue indispensable para `V2` y `V4`, donde varios `CREATE PROCEDURE`/`CREATE FUNCTION` deben ir en su propio lote.

2. **Las variables `DECLARE` no sobreviven a un `GO`.** En `V4`, el bloque de cifrado de contraseñas (`DECLARE @PasswordPlano ...`) tiene que declararse *después* del `OPEN SYMMETRIC KEY` dentro del mismo lote, porque cada `GO` reinicia el contexto de variables locales de T-SQL. Si una migración futura necesita reutilizar una variable entre dos bloques separados por `GO`, hay que volver a declararla o usar una tabla temporal/variable de sesión, ya que Flyway respeta el comportamiento estándar de `sqlcmd` en este punto, no lo modifica.

3. **`mixed = true` fue obligatorio por instrucciones no transaccionales.** Algunas instrucciones de `V4` (creación de `LOGIN`, `MASTER KEY`, certificados) no pueden combinarse libremente con DML dentro de la misma transacción implícita que Flyway intenta abrir por migración. Sin `mixed = true`, la migración fallaba con errores de SQL Server relacionados con operaciones que deben ejecutarse fuera de una transacción explícita.

4. **`CHECK_POLICY = ON` se comporta distinto en SQL Server sobre Linux/Docker.** Los logins de `V4` definen `CHECK_POLICY = ON`, pensado para aplicar las políticas de complejidad de contraseñas de Windows. Al correr SQL Server en un contenedor Linux (como en el `docker-compose` del MVP), esa política del sistema operativo no existe realmente, por lo que la validación es más laxa que en una instancia Windows nativa — un hallazgo importante para no asumir el mismo nivel de robustez de contraseñas entre ambientes de desarrollo y producción.

5. **Checksum mismatch al editar una migración ya aplicada.** Al modificar accidentalmente `V6` (agregar un índice extra) después de haberla corrido una vez en local, `flyway info`/`flyway migrate` detectó el cambio de checksum y se negó a continuar. Esto confirmó en la práctica la garantía de inmutabilidad de Flyway: la solución fue revertir el archivo y crear una nueva migración (`V12`) con el índice adicional, en lugar de tocar `V6`.

6. **Los scripts de deadlock (`V9`, `V10`, `V11`) se versionan con Flyway, pero su demostración no corre dentro de `flyway migrate`.** Flyway aplica cada migración de forma **secuencial sobre una sola conexión**. Como estas migraciones solo *crean* los Stored Procedures de demostración (no los ejecutan), el escenario de deadlock en sí se reprodujo manualmente abriendo **dos sesiones simultáneas en SSMS** y ejecutando, por ejemplo, `demo.usp_Demo_DeadlockWrite_A` en una pestaña y `demo.usp_Demo_DeadlockWrite_B` en otra casi al mismo tiempo. El versionado garantiza que todo el equipo tenga el mismo SP de demostración disponible, pero la concurrencia real no puede simularse dentro del propio proceso de migración.

7. **`IF NOT EXISTS` como práctica defensiva en seeding (`V7`).** Aunque Flyway garantiza que `V7` solo se ejecute una vez por base de datos (vía `flyway_schema_history`), el equipo agregó validaciones `IF NOT EXISTS (SELECT 1 FROM dbo.Players WHERE username = ...)` por si el script llegara a ejecutarse manualmente fuera de Flyway (por ejemplo, copiado y pegado en SSMS durante una demo en vivo) — escenario que sí ocurrió durante las pruebas del *live coding*.

8. **`cleanDisabled = true` evitó un incidente real.** Durante las pruebas, un integrante intentó usar `flyway clean` pensando que solo limpiaba la tabla de historial; al estar desactivado por configuración, el comando se rechazó con un error explícito en lugar de borrar todos los objetos de `dbo`, `demo` y `Security` de la base de datos compartida de pruebas.

9. **Cadena de conexión JDBC requiere `trustServerCertificate=true` en ambientes locales/Docker.** Sin este parámetro, la primera conexión de Flyway contra la instancia de SQL Server en contenedor falló por un error de confianza del certificado TLS autogenerado, antes de poder ejecutar siquiera `V1`.

10. **`baselineOnMigrate` fue necesario al integrar una base de datos ya creada manualmente por error.** En una prueba, un integrante había creado las tablas de `V1` directamente en SSMS antes de adoptar Flyway en su ambiente. `flyway baseline -baselineVersion=1` permitió decirle a Flyway "asume que la versión 1 ya está aplicada" sin tener que borrar y recrear esa base, evitando además el error típico de "tabla ya existe" al intentar correr `V1` de nuevo.

---

## 9. Buenas prácticas adoptadas por el equipo

- Nunca editar una migración `V*` ya commiteada y aplicada en cualquier ambiente compartido; siempre crear una nueva versión.
- Mantener un único origen de numeración secuencial (`V1`…`V11`…) para evitar colisiones de versión entre ramas de distintos integrantes; los conflictos de número de versión se resuelven en el Pull Request, antes de mezclar a la rama principal.
- `flyway info` se corre como parte de la verificación previa a cada demo/revisión, para confirmar que el ambiente del presentador tiene exactamente el mismo estado que el resto del equipo.
- Los scripts de demostración de concurrencia (`V9`–`V11`) se documentan con instrucciones explícitas de "cómo reproducir manualmente con dos/tres sesiones", ya que Flyway los versiona pero no los ejecuta de forma concurrente.

---

## 10. Referencias

- Documentación oficial de Flyway (Redgate): https://documentation.red-gate.com/flyway
- Convenciones de nombres de migraciones: https://documentation.red-gate.com/flyway/flyway-cli-and-api/concepts/migrations
- Comando Undo y diferencias entre ediciones: https://documentation.red-gate.com/flyway/flyway-cli-and-api/commands/undo
- Driver y configuración específica de SQL Server: https://documentation.red-gate.com/flyway/reference/database-driver-reference/sql-server-database
