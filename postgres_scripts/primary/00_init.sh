#!/bin/bash
# postgres_scripts/primary/00_init.sh

set -e

# Crear directorio para archivos WAL archivados
mkdir -p /var/lib/postgresql/archives
chown postgres:postgres /var/lib/postgresql/archives
chmod 700 /var/lib/postgresql/archives

echo "✓ Directorio de archivos WAL creado"

# Copiar configuraciones personalizadas
if [ -f /docker-entrypoint-initdb.d/postgresql.conf ]; then
    cp /docker-entrypoint-initdb.d/postgresql.conf $PGDATA/postgresql.conf
    echo "✓ postgresql.conf aplicado"
fi

if [ -f /docker-entrypoint-initdb.d/pg_hba.conf ]; then
    cp /docker-entrypoint-initdb.d/pg_hba.conf $PGDATA/pg_hba.conf
    echo "✓ pg_hba.conf aplicado"
fi