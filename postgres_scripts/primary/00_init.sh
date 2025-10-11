#!/bin/bash
# postgres_scripts/primary/00_init.sh

set -e

echo "=== Configurando PostgreSQL primario ==="

# Crear directorio para archivos WAL archivados
mkdir -p /var/lib/postgresql/archives
chown postgres:postgres /var/lib/postgresql/archives
chmod 700 /var/lib/postgresql/archives
echo "✓ Directorio de archivos WAL creado"

# Sobrescribir postgresql.conf
cat >> $PGDATA/postgresql.conf <<EOF

# ============================================
# CONFIGURACIÓN DE REPLICACIÓN
# ============================================

# Escuchar en todas las interfaces
listen_addresses = '*'

# Nivel de WAL para replicación
wal_level = replica

# Número de conexiones de replicación
max_wal_senders = 10

# Tamaño de WAL a mantener
wal_keep_size = 64

# Archivado de WAL
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/archives/%f && cp %p /var/lib/postgresql/archives/%f'

# Hot standby
hot_standby = on

# Conexiones máximas
max_connections = 100
EOF

echo "✓ postgresql.conf configurado"

# Sobrescribir pg_hba.conf
cat > $PGDATA/pg_hba.conf <<EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             all                                     trust

# IPv4 local connections
host    all             all             127.0.0.1/32            trust

# Allow all from Docker network
host    all             all             0.0.0.0/0               md5

# IPv6 local connections
host    all             all             ::1/128                 trust

# Replication connections
host    replication     all             0.0.0.0/0               md5
EOF

echo "✓ pg_hba.conf configurado"