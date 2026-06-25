CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS users (
    userid SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    second_name VARCHAR(50),
    lastname VARCHAR(50) NOT NULL,
    second_lastname VARCHAR(50),
    cedula VARCHAR(20) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted BOOLEAN DEFAULT FALSE                 
);

CREATE TABLE IF NOT EXISTS biometric_validations (
    biometric_id SERIAL PRIMARY KEY,
    userid INT NOT NULL REFERENCES users(userid), 
    liveness_check BOOLEAN DEFAULT FALSE,
    confidence_score DECIMAL(5,2),
    validated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS criminal_records (
    record_id SERIAL PRIMARY KEY,
    userid INT NOT NULL REFERENCES users(userid),
    status VARCHAR(30) DEFAULT 'Sin antecedentes', 
    is_current BOOLEAN DEFAULT TRUE,
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS location_logs (
    log_id SERIAL PRIMARY KEY,
    userid INT NOT NULL REFERENCES users(userid),
    position GEOGRAPHY(POINT, 4326) NOT NULL, 
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_posicion_gist ON location_logs USING GIST (position);

-- Script para insertar los usuarios:

-- A. Insertar 3,000 usuarios
INSERT INTO users (first_name, second_name, lastname, second_lastname, cedula)
SELECT 
    'Nombre_' || i, 
    'Segundo_' || i,
    'Apellido1_' || i,
    'Apellido2_' || i,
    (100000000 + i)::text
FROM generate_series(1, 3000) s(i);

-- B. Insertar registros criminales (80% Limpios, 20% Con antecedentes)
INSERT INTO criminal_records (userid, status)
SELECT 
    userid,
    CASE 
        WHEN random() < 0.8 THEN 'Sin antecedentes'
        ELSE 'Con antecedentes'
    END
FROM users;

-- C. Insertar Validaciones (Todos pasaron con puntaje aleatorio)
INSERT INTO biometric_validations (userid, liveness_check, confidence_score)
SELECT userid, TRUE, (85 + random() * 14)::decimal(5,2)
FROM users;

-- D. Insertar 3 puntos GPS por usuario en zonas de Costa Rica
INSERT INTO location_logs (userid, position)
SELECT 
    u.userid,
    ST_SetSRID(ST_MakePoint(
        -84.1 + (random() - 0.5) * 0.02, -- Longitud aprox GAM
        9.9 + (random() - 0.5) * 0.02    -- Latitud aprox GAM
    ), 4326)::geography
FROM users u
CROSS JOIN generate_series(1, 3);