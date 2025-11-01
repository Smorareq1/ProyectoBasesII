#!/bin/bash
# test-backup-strategy.sh - Prueba completa de la estrategia de respaldos

set -e  # Detener si hay error

# Cargar variables del .env
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

echo "═══════════════════════════════════════════════════════════"
echo "  PRUEBA DE ESTRATEGIA DE RESPALDOS - POLLO SANJUANERO"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verificar que el primario esté disponible
echo "Verificando servidor primario..."
if ! docker exec postgres-primary pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} > /dev/null 2>&1; then
  echo "ERROR: El servidor primario no está disponible"
  echo "Ejecuta: docker-compose up -d"
  exit 1
fi
echo "✓ Servidor primario disponible"
echo ""

# Limpiar backups anteriores
echo "Preparando directorios de backup..."
rm -rf ./backups/*
mkdir -p ./backups/full
mkdir -p ./backups/incremental
echo "✓ Directorios preparados"
echo ""

# Función para insertar datos
insert_data() {
  local mensaje=$1
  echo "  → Insertando: $mensaje"
  docker exec postgres-primary psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c \
    "INSERT INTO test_replication (mensaje) VALUES ('$mensaje');" > /dev/null
  echo "  ✓ Datos insertados"
}

# Función para hacer backup
do_backup() {
  local tipo=$1
  if [ "$tipo" == "full" ]; then
    echo "  → Ejecutando FULL backup..."
    ./backup.sh full > /tmp/backup_output.log 2>&1
    if [ $? -eq 0 ]; then
      echo "  ✓ Full backup completado"
    else
      echo "  ✗ Error en full backup"
      cat /tmp/backup_output.log
    fi
  else
    echo "  → Ejecutando backup incremental..."
    ./backup.sh incremental > /tmp/backup_output.log 2>&1
    if [ $? -eq 0 ]; then
      echo "  ✓ Backup incremental completado"
    else
      echo "  ✗ Error en backup incremental"
      cat /tmp/backup_output.log
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# SIMULACIÓN DE LA SEMANA
# ═══════════════════════════════════════════════════════════

# DÍA 1 - LUNES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 DÍA 1 - LUNES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
insert_data "Lunes - Ventas del dia: Q15,450.00"
do_backup incremental
echo ""
sleep 2

# DÍA 2 - MARTES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 DÍA 2 - MARTES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
insert_data "Martes - Inventario actualizado: 500 unidades"
do_backup incremental
echo ""
sleep 2

# DÍA 3 - MIÉRCOLES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 DÍA 3 - MIÉRCOLES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
insert_data "Miercoles - Pedidos procesados: 45 ordenes"
do_backup incremental
echo ""
sleep 2

# DÍA 4 - JUEVES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 DÍA 4 - JUEVES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
insert_data "Jueves - Produccion: 1200 pollos procesados"
do_backup incremental
echo ""
sleep 2

# DÍA 5 - VIERNES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 DÍA 5 - VIERNES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
insert_data "Viernes - Ventas fin de semana: Q22,300.00"
do_backup incremental
echo ""
sleep 2

# DÍA 6 - SÁBADO
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 DÍA 6 - SÁBADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
insert_data "Sabado - Inventario fin de semana: 350 unidades"
do_backup incremental
echo ""
sleep 2

# DÍA 7 - DOMINGO (FULL BACKUP)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 DÍA 7 - DOMINGO (FULL BACKUP SEMANAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
insert_data "Domingo - Cierre semanal: Q98,750.00"
do_backup full
echo ""

# ═══════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  📊 RESUMEN FINAL DE BACKUPS"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "📦 Full Backups creados:"
echo "─────────────────────────────────────────────────────────"
if ls ./backups/full/*.tar.gz 1> /dev/null 2>&1; then
  ls -lh ./backups/full/*.tar.gz | awk '{print "  " $9 " - " $5}'
else
  echo "  (Sin full backups)"
fi
echo ""

echo "📂 Backups Incrementales creados:"
echo "─────────────────────────────────────────────────────────"
INCR_COUNT=$(ls -d ./backups/incremental/wal_* 2>/dev/null | wc -l)
echo "  Total: $INCR_COUNT backups incrementales (WAL)"
if [ $INCR_COUNT -gt 0 ]; then
  echo ""
  echo "  Últimos 3 backups incrementales:"
  ls -d ./backups/incremental/wal_* 2>/dev/null | tail -3 | while read dir; do
    FILE_COUNT=$(ls -1 "$dir" 2>/dev/null | wc -l)
    echo "    $(basename $dir) - $FILE_COUNT archivos WAL"
  done
fi
echo ""

echo "💾 Espacio total usado por backups:"
echo "─────────────────────────────────────────────────────────"
du -sh ./backups/
echo ""

echo "📝 Datos insertados durante la semana:"
echo "─────────────────────────────────────────────────────────"
docker exec postgres-primary psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c \
  "SELECT id, mensaje, fecha_creacion FROM test_replication ORDER BY id DESC LIMIT 10;"
echo ""

echo "📊 Estado de archivos WAL en el servidor:"
echo "─────────────────────────────────────────────────────────"
WAL_COUNT=$(docker exec postgres-primary bash -c "ls -1 /var/lib/postgresql/archives/ 2>/dev/null | wc -l")
echo "  Total de archivos WAL archivados: $WAL_COUNT"
echo ""
echo "  Últimos 5 archivos WAL:"
docker exec postgres-primary bash -c "ls -lh /var/lib/postgresql/archives/ | tail -5"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ PRUEBA COMPLETADA EXITOSAMENTE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📌 Resumen:"
FULL_COUNT=$(ls ./backups/full/*.sql.gz ./backups/full/*.tar.gz 2>/dev/null | wc -l)
echo "  • Full backups: $FULL_COUNT"
echo "  • Backups incrementales: $INCR_COUNT"
echo "  • Datos insertados: 7 registros de la semana"
echo "  • Archivos WAL: $WAL_COUNT"
echo ""
echo "💡 Siguiente paso: Prueba el failover con ./failover.sh"
echo ""