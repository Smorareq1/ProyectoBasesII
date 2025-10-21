#!/bin/bash
# postgres_scripts/replica/entrypoint.sh

set -e

MODE=${1:-replica}
export PGDATA=/var/lib/postgresql/data

echo "=== Starting PostgreSQL in $MODE mode ==="
echo "PGDATA: $PGDATA"

# Esperar a que el primario esté listo
echo "Waiting for primary to be ready..."
sleep 10

COUNTER=0
MAX_TRIES=60

while [ $COUNTER -lt $MAX_TRIES ]; do
  if PGPASSWORD=adminpass psql -h postgres-primary -p 5432 -U admin -d sanjuanero_db -c "SELECT 1" >/dev/null 2>&1; then
    echo "✓ Primary is ready and accepting SQL connections!"
    break
  fi

  COUNTER=$((COUNTER+1))

  if [ $((COUNTER % 10)) -eq 0 ]; then
    echo "Still waiting... attempt $COUNTER/$MAX_TRIES"
  fi

  sleep 3
done

if [ $COUNTER -eq $MAX_TRIES ]; then
  echo "ERROR: Could not connect to primary"
  exit 1
fi

# Verificar si ya está inicializado
if [ -f "$PGDATA/PG_VERSION" ]; then
  echo "Data directory already initialized, starting PostgreSQL..."
  exec postgres
fi

# Inicializar desde el primario
echo "Initializing replica from primary..."
rm -rf $PGDATA/*

echo "Running pg_basebackup from postgres-primary:5432..."
PGPASSWORD=adminpass pg_basebackup \
  -h postgres-primary \
  -p 5432 \
  -U admin \
  -D $PGDATA \
  -Fp \
  -Xs \
  -P \
  -R \
  -v

echo "✓ Backup completed!"

# Configurar hot_standby
echo "hot_standby = on" >> $PGDATA/postgresql.conf

# Ajustar permisos para el usuario postgres
chmod 700 $PGDATA

echo "✓ Configured as $MODE"
echo "Starting PostgreSQL server..."

# Iniciar PostgreSQL como usuario postgres
exec postgres