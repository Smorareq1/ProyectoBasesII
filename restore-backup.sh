#!/bin/bash
# restore-backup.sh - Restaurar desde backup

echo "═══════════════════════════════════════════════════════════"
echo "  RESTAURACIÓN DE BACKUP - POLLO SANJUANERO"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Listar backups disponibles con números
echo "Backups Full disponibles:"
echo ""
BACKUPS=(./backups/full/*.sql.gz)

if [ ${#BACKUPS[@]} -eq 0 ] || [ ! -f "${BACKUPS[0]}" ]; then
  echo "ERROR: No hay backups disponibles"
  exit 1
fi

# Mostrar lista numerada
i=1
for backup in "${BACKUPS[@]}"; do
  filename=$(basename "$backup")
  size=$(du -h "$backup" | cut -f1)
  echo "  [$i] $filename ($size)"
  i=$((i+1))
done

echo ""
read -p "Seleccione el número del backup a restaurar (1-$((i-1))): " SELECTION

# Validar selección
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -ge "$i" ]; then
  echo "ERROR: Selección inválida"
  exit 1
fi

# Obtener archivo seleccionado
BACKUP_FILE="${BACKUPS[$((SELECTION-1))]}"
BACKUP_NAME=$(basename "$BACKUP_FILE")

echo ""
echo "Backup seleccionado: $BACKUP_NAME"
echo ""
echo "⚠️  ADVERTENCIA: Esto eliminará TODOS los datos actuales"
read -p "¿Continuar? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Restauración cancelada"
  exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  INICIANDO RESTAURACIÓN"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "1. Deteniendo y eliminando todos los contenedores..."
docker-compose down -v

echo ""
echo "2. Verificando que los volúmenes se eliminaron..."
docker volume ls | grep proyectobases

echo ""
echo "3. Iniciando solo el primario con BD vacía..."
docker-compose up -d postgres-primary

echo ""
echo "4. Esperando a que PostgreSQL inicie..."
sleep 15

# Verificar que esté listo
ATTEMPTS=0
MAX_ATTEMPTS=30
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  if docker exec postgres-primary pg_isready -U admin > /dev/null 2>&1; then
    echo "✓ PostgreSQL está listo"
    break
  fi
  ATTEMPTS=$((ATTEMPTS+1))
  echo "Esperando... ($ATTEMPTS/$MAX_ATTEMPTS)"
  sleep 2
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo "ERROR: PostgreSQL no inició correctamente"
  exit 1
fi

echo ""
echo "5. Restaurando backup SQL..."
echo "(Esto puede tomar unos segundos...)"

# Filtrar solo errores reales, no warnings
gunzip -c "$BACKUP_FILE" | \
  docker exec -i postgres-primary psql -U admin -d sanjuanero_db 2>&1 | \
  grep -E "^ERROR|^FATAL" > /tmp/restore_errors.log

if [ -s /tmp/restore_errors.log ]; then
  echo "⚠ Se encontraron errores durante la restauración:"
  cat /tmp/restore_errors.log
  echo ""
  read -p "¿Continuar de todos modos? (yes/no): " CONTINUE
  if [ "$CONTINUE" != "yes" ]; then
    exit 1
  fi
else
  echo "✓ Backup restaurado sin errores"
fi

echo ""
echo "6. Iniciando réplicas..."
docker-compose up -d postgres-standby postgres-replica-readonly

echo ""
echo "Esperando a que las réplicas se conecten..."
sleep 25

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ RESTAURACIÓN COMPLETADA"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "📊 Verificación de datos restaurados:"
echo "─────────────────────────────────────────────────────────"
docker exec postgres-primary psql -U admin -d sanjuanero_db -c \
  "SELECT COUNT(*) as total_registros FROM test_replication;"

echo ""
echo "📝 Últimos registros restaurados:"
echo "─────────────────────────────────────────────────────────"
docker exec postgres-primary psql -U admin -d sanjuanero_db -c \
  "SELECT id, mensaje, fecha_creacion FROM test_replication ORDER BY id;"

echo ""
echo "🔄 Estado de la arquitectura:"
echo "─────────────────────────────────────────────────────────"
docker-compose ps

echo ""
echo "📡 Estado de replicación:"
echo "─────────────────────────────────────────────────────────"
sleep 5
docker exec postgres-primary psql -U admin -d sanjuanero_db -c \
  "SELECT application_name, state, sync_state FROM pg_stat_replication;" 2>/dev/null || \
  echo "(Las réplicas aún se están conectando...)"

echo ""
echo "💡 Tip: Verifica que las réplicas tengan los mismos datos:"
echo "  docker exec postgres-standby psql -U admin -d sanjuanero_db -c 'SELECT COUNT(*) FROM test_replication;'"
echo ""