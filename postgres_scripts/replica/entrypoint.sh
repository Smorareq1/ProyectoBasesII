#!/bin/bash
# postgres_scripts/replica/entrypoint.sh

set -e

MODE=${1:-replica}

echo "=== Starting PostgreSQL in $MODE mode ==="

# Esperar a que el primario esté completamente listo
echo "Waiting for primary to be ready..."
until PGPASSWORD=adminpass pg_isready -h postgres-primary -p 5432 -U admin -d sanjuanero_db -t 30; do
  echo "Primary is unavailable - sleeping..."
  sleep 3
done

echo "✓ Primary is ready!"

# Si el directorio de datos está vacío, hacer backup
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Initializing replica from primary..."

  # Limpiar el directorio de datos
  rm -rf ${PGDATA}/*

  # Hacer el backup base SIN solicitar contraseña
  echo "Running pg_basebackup..."
  PGPASSWORD=adminpass pg_basebackup \
    -h postgres-primary \
    -p 5432 \
    -U admin \
    -D ${PGDATA} \
    -Fp \
    -Xs \
    -P \
    -R \
    -v

  echo "✓ Backup completed successfully!"

  # Configurar según el modo
  if [ "$MODE" = "standby" ]; then
    echo "Configuring as HOT STANDBY (can be promoted)..."
    echo "hot_standby = on" >> ${PGDATA}/postgresql.conf
  else
    echo "Configuring as READ-ONLY REPLICA..."
    echo "hot_standby = on" >> ${PGDATA}/postgresql.conf
  fi

  # Ajustar permisos
  chmod 700 ${PGDATA}
  chown -R postgres:postgres ${PGDATA} 2>/dev/null || true
fi

# Iniciar PostgreSQL
echo "Starting PostgreSQL server..."
exec postgres