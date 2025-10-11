#!/bin/bash
# backup.sh - Estrategia de respaldos con retención de 7 días

BACKUP_DIR="./backups"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
DAY_OF_WEEK=$(date +%u)  # 1=Lunes, 7=Domingo

echo "=== ESTRATEGIA DE RESPALDOS POLLO SANJUANERO ==="
echo "Fecha: $(date)"
echo "Directorio: $BACKUP_DIR"
echo "Retención: $RETENTION_DAYS días"
echo ""

# Crear directorio de backups si no existe
mkdir -p $BACKUP_DIR/full
mkdir -p $BACKUP_DIR/incremental
mkdir -p $BACKUP_DIR/wal

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
  # FULL BACKUP (Semanal o manual)
  echo "=== EJECUTANDO FULL BACKUP ==="
  BACKUP_FILE="$BACKUP_DIR/full/full_backup_$DATE.tar.gz"

  echo "Iniciando pg_basebackup..."
  echo "Esto puede tomar unos minutos..."

  if docker exec postgres-primary pg_basebackup -U admin -D - -Ft -z -P > "$BACKUP_FILE"; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Full backup completado: $BACKUP_FILE"
    echo "  Tamaño: $BACKUP_SIZE"
    echo ""
  else
    echo "ERROR: Full backup falló"
    exit 1
  fi
else
  # BACKUP INCREMENTAL (Diario)
  echo "=== EJECUTANDO BACKUP INCREMENTAL ==="
  echo "Forzando cambio de segmento WAL..."
  docker exec postgres-primary psql -U admin -d sanjuanero_db -c "SELECT pg_switch_wal();" > /dev/null

  echo "Copiando archivos WAL archivados..."
  INCREMENTAL_DIR="$BACKUP_DIR/incremental/wal_$DATE"
  mkdir -p "$INCREMENTAL_DIR"

  # Copiar archivos WAL del contenedor
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

# Mostrar archivos WAL actuales en el primario
echo "3. Estado de archivos WAL en el primario:"
docker exec postgres-primary bash -c "ls -lh /var/lib/postgresql/archives/ 2>/dev/null | tail -10" || echo "  (Sin archivos WAL archivados aún)"
echo ""

# Información del último checkpoint
echo "4. Información del último checkpoint:"
docker exec postgres-primary psql -U admin -d sanjuanero_db -c "SELECT pg_current_wal_lsn(), pg_last_wal_replay_lsn();" 2>/dev/null || true
echo ""

# Limpieza de backups antiguos
echo "5. Limpieza de backups antiguos (>$RETENTION_DAYS días)..."
DELETED_FULL=$(find $BACKUP_DIR/full -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS -print -delete | wc -l)
DELETED_INCR=$(find $BACKUP_DIR/incremental -type d -name "wal_*" -mtime +$RETENTION_DAYS -print -delete | wc -l)

echo "  Full backups eliminados: $DELETED_FULL"
echo "  Incrementales eliminados: $DELETED_INCR"
echo ""

# Resumen de backups actuales
echo "6. Resumen de backups actuales:"
echo ""
echo "Full Backups:"
ls -lh $BACKUP_DIR/full/ 2>/dev/null || echo "  (Sin backups full)"
echo ""
echo "Backups Incrementales:"
ls -ld $BACKUP_DIR/incremental/wal_* 2>/dev/null || echo "  (Sin backups incrementales)"
echo ""

# Calcular espacio usado
TOTAL_SIZE=$(du -sh $BACKUP_DIR 2>/dev/null | cut -f1)
echo "Espacio total usado por backups: $TOTAL_SIZE"
echo ""

echo "=== BACKUP COMPLETADO EXITOSAMENTE ==="