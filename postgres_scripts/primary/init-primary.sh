#!/bin/bash
# postgres_scripts/primary/01_init-primary.sh

set -e

echo "=== Configurando nodo primario ==="

# Crear usuario de replicación
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Crear usuario de replicación
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
            CREATE USER replicator WITH REPLICATION LOGIN PASSWORD 'replicapass';
        END IF;
    END
    \$\$;

    -- Crear tabla de prueba
    CREATE TABLE IF NOT EXISTS test_replication (
        id SERIAL PRIMARY KEY,
        mensaje TEXT,
        fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Insertar datos iniciales
    INSERT INTO test_replication (mensaje) VALUES 
        ('Primer registro - Nodo Primario'),
        ('Segundo registro - Nodo Primario'),
        ('Tercer registro - Nodo Primario');
EOSQL

echo "✓ Usuario de replicación creado"
echo "✓ Tabla de prueba creada"
echo "✓ Configuración del primario completada"