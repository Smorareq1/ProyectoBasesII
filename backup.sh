#!/bin/bash
# backup.sh - Estrategia de respaldos con retención de 7 días

# Cargar variables del .env
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

BACKUP_DIR="./backups"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
DAY_OF_WEEK=$(date +%u)

echo "=== ESTRATEGIA DE RESPALDOS POLLO SANJUANERO ==="
echo "Fecha: $(date)"
echo "Directorio: ./backups"
echo "Retención: $RETENTION_DAYS días"
echo ""

mkdir -p $BACKUP_DIR/full
mkdir -p $BACKUP_DIR/incremental

echo "1. Verificando estado del servidor primario..."
if ! docker exec postgres-primary pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} > /dev/null 2>&1; then
  echo "ERROR: El servidor primario no está disponible"
  exit 1
fi
echo "✓ Servidor primario operacional"
echo ""

# Determinar tipo de backup
if [ "$1" == "full" ]; then
  BACKUP_TYPE="full"
elif [ "$1" == "incremental" ]; then
  BACKUP_TYPE="incremental"
elif [ $DAY_OF_WEEK -eq 7 ]; then
  BACKUP_TYPE="full"
else
  BACKUP_TYPE="incremental"
fi

echo "2. Tipo de backup: $BACKUP_TYPE"
echo ""

if [ "$BACKUP_TYPE" == "full" ]; then
  # FULL BACKUP - Versión simplificada con pg_dump
  echo "=== EJECUTANDO FULL BACKUP ==="
  BACKUP_FILE="$BACKUP_DIR/full/full_backup_$DATE.sql.gz"

  echo "Creando dump completo de la base de datos..."

  docker exec postgres-primary pg_dump \
    -U ${POSTGRES_USER} \
    -d ${POSTGRES_DB} \
    --verbose 2>&1 | gzip > "$BACKUP_FILE"

  if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Full backup completado: $BACKUP_FILE"
    echo "  Tamaño: $BACKUP_SIZE"
    echo ""
  else
    echo "ERROR: Full backup falló"
    rm -f "$BACKUP_FILE"
    exit 1
  fi
else
  # BACKUP INCREMENTAL
  echo "=== EJECUTANDO BACKUP INCREMENTAL ==="
  echo "Forzando cambio de segmento WAL..."
  docker exec postgres-primary psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT pg_switch_wal();" > /dev/null

  echo "Copiando archivos WAL archivados..."
  INCREMENTAL_DIR="$BACKUP_DIR/incremental/wal_$DATE"
  mkdir -p "$INCREMENTAL_DIR"

  # Limpiar /tmp en el contenedor
  docker exec postgres-primary bash -c "rm -rf /tmp/wal_backup && mkdir -p /tmp/wal_backup" 2>/dev/null

  # Copiar WAL a tmp
  docker exec postgres-primary bash -c "cp /var/lib/postgresql/archives/* /tmp/wal_backup/" 2>/dev/null || true

  # Copiar del contenedor al host
  docker cp postgres-primary:/tmp/wal_backup/. "$INCREMENTAL_DIR/" 2>/dev/null || true

  # Limpiar tmp
  docker exec postgres-primary bash -c "rm -rf /tmp/wal_backup" 2>/dev/null

  WAL_COUNT=$(ls -1 "$INCREMENTAL_DIR" 2>/dev/null | wc -l)

  if [ $WAL_COUNT -gt 0 ]; then
    WAL_SIZE=$(du -sh "$INCREMENTAL_DIR" | cut -f1)
    echo "✓ Backup incremental completado: $INCREMENTAL_DIR"
    echo "  Archivos WAL copiados: $WAL_COUNT"
    echo "  Tamaño total: $WAL_SIZE"
    echo ""
  else
    echo "⚠ No se encontraron archivos WAL nuevos"
    echo ""
  fi
fi

echo "3. Estado de archivos WAL en el primario:"
docker exec postgres-primary bash -c "ls -lh /var/lib/postgresql/archives/ 2>/dev/null | tail -10" || echo "  (Sin archivos WAL)"
echo ""

echo "4. Información del último checkpoint:"
docker exec postgres-primary psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT pg_current_wal_lsn(), pg_last_wal_replay_lsn();" 2>/dev/null || true
echo ""

echo "5. Limpieza de backups antiguos (>$RETENTION_DAYS días)..."
find $BACKUP_DIR/full -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null
find $BACKUP_DIR/incremental -type d -name "wal_*" -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null

echo "✓ Limpieza completada"
echo ""

echo "6. Resumen de backups actuales:"
echo ""
echo "Full Backups:"
FULL_COUNT=$(ls $BACKUP_DIR/full/*.{gz,tar.gz} 2>/dev/null | wc -l)
if [ $FULL_COUNT -gt 0 ]; then
  ls -lh $BACKUP_DIR/full/
else
  echo "  (Sin backups full)"
fi
echo ""
echo "Backups Incrementales:"
INCR_COUNT=$(ls -d $BACKUP_DIR/incremental/wal_* 2>/dev/null | wc -l)
echo "  Total: $INCR_COUNT backups incrementales"
if [ $INCR_COUNT -gt 0 ]; then
  echo "  Últimos 3:"
  ls -ld $BACKUP_DIR/incremental/wal_* 2>/dev/null | tail -3
fi
echo ""

TOTAL_SIZE=$(du -sh $BACKUP_DIR 2>/dev/null | cut -f1)
echo "Espacio total usado: $TOTAL_SIZE"
echo ""

echo "=== BACKUP COMPLETADO EXITOSAMENTE ==="