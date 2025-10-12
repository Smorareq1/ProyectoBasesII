#!/bin/bash
# backup.sh - Estrategia de respaldos con retención de 7 días

BACKUP_DIR="./backups"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
DAY_OF_WEEK=$(date +%u)

echo "=== ESTRATEGIA DE RESPALDOS POLLO SANJUANERO ==="
echo "Fecha: $(date)"
echo "Directorio: $BACKUP_DIR"
echo "Retención: $RETENTION_DAYS días"
echo ""

mkdir -p $BACKUP_DIR/full
mkdir -p $BACKUP_DIR/incremental
# Verificar que el primario esté disponible
echo "1. Verificando estado del servidor primario..."
if ! docker exec postgres-primary pg_isready -U admin > /dev/null 2>&1; then
  echo "ERROR: El servidor primario no está disponible"
  exit 1
fi
echo "✓ Servidor primario operacional"
echo ""

# Determinar tipo de backup
BACKUP_TYPE="incremental"
if [ "$1" == "full" ] || [ $DAY_OF_WEEK -eq 7 ]; then
  BACKUP_TYPE="full"
fi

echo "2. Tipo de backup: $BACKUP_TYPE"
echo ""

if [ "$BACKUP_TYPE" == "full" ]; then
  # FULL BACKUP
  echo "=== EJECUTANDO FULL BACKUP ==="
  BACKUP_FILE="$BACKUP_DIR/full/full_backup_$DATE.tar.gz"
  TEMP_BACKUP_DIR="/tmp/pg_backup_$DATE"

  echo "Creando backup en el contenedor..."

  # Crear directorio temporal
  docker exec postgres-primary mkdir -p $TEMP_BACKUP_DIR

  # Hacer el backup (formato tar comprimido)
  docker exec -e PGPASSWORD=replicapass postgres-primary pg_basebackup \
    -h localhost \
    -U replicator \
    -D $TEMP_BACKUP_DIR \
    -Ft \
    -z \
    -P

  if [ $? -eq 0 ]; then
    echo "Backup creado, copiando al host..."

    # Ver qué archivos se crearon
    echo "Archivos generados:"
    docker exec postgres-primary ls -lh $TEMP_BACKUP_DIR

    # Copiar TODO el directorio
    docker cp postgres-primary:$TEMP_BACKUP_DIR/. "$BACKUP_DIR/full/backup_$DATE/"

    # Comprimir todo en un solo archivo
    cd "$BACKUP_DIR/full"
    tar -czf "full_backup_$DATE.tar.gz" "backup_$DATE"
    rm -rf "backup_$DATE"
    cd - > /dev/null

    # Limpiar el contenedor
    docker exec postgres-primary rm -rf $TEMP_BACKUP_DIR

    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Full backup completado: $BACKUP_FILE"
    echo "  Tamaño: $BACKUP_SIZE"
    echo ""
  else
    echo "ERROR: Full backup falló"
    docker exec postgres-primary rm -rf $TEMP_BACKUP_DIR 2>/dev/null
    exit 1
  fi
else
  # BACKUP INCREMENTAL
  echo "=== EJECUTANDO BACKUP INCREMENTAL ==="
  echo "Forzando cambio de segmento WAL..."
  docker exec postgres-primary psql -U admin -d sanjuanero_db -c "SELECT pg_switch_wal();" > /dev/null

  echo "Copiando archivos WAL archivados..."
  INCREMENTAL_DIR="$BACKUP_DIR/incremental/wal_$DATE"
  mkdir -p "$INCREMENTAL_DIR"

  docker exec postgres-primary bash -c "cp /var/lib/postgresql/archives/* /tmp/" 2>/dev/null || true
  docker cp postgres-primary:/tmp/. "$INCREMENTAL_DIR/" 2>/dev/null || true

  WAL_COUNT=$(ls -1 "$INCREMENTAL_DIR" 2>/dev/null | wc -l)

  if [ $WAL_COUNT -gt 0 ]; then
    echo "✓ Backup incremental completado: $INCREMENTAL_DIR"
    echo "  Archivos WAL copiados: $WAL_COUNT"
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
docker exec postgres-primary psql -U admin -d sanjuanero_db -c "SELECT pg_current_wal_lsn(), pg_last_wal_replay_lsn();" 2>/dev/null || true
echo ""

echo "5. Limpieza de backups antiguos (>$RETENTION_DAYS días)..."
DELETED_FULL=$(find $BACKUP_DIR/full -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null | wc -l)
DELETED_INCR=$(find $BACKUP_DIR/incremental -type d -name "wal_*" -mtime +$RETENTION_DAYS -delete 2>/dev/null | wc -l)

echo "  Full backups eliminados: $DELETED_FULL"
echo "  Incrementales eliminados: $DELETED_INCR"
echo ""

echo "6. Resumen de backups actuales:"
echo ""
echo "Full Backups:"
ls -lh $BACKUP_DIR/full/*.tar.gz 2>/dev/null || echo "  (Sin backups full)"
echo ""
echo "Backups Incrementales:"
INCR_COUNT=$(ls -d $BACKUP_DIR/incremental/wal_* 2>/dev/null | wc -l)
echo "  Total: $INCR_COUNT backups incrementales"
ls -ld $BACKUP_DIR/incremental/wal_* 2>/dev/null | tail -3 || echo "  (Sin incrementales)"
echo ""

TOTAL_SIZE=$(du -sh $BACKUP_DIR 2>/dev/null | cut -f1)
echo "Espacio total usado: $TOTAL_SIZE"
echo ""

echo "=== BACKUP COMPLETADO EXITOSAMENTE ==="