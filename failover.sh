#!/bin/bash
# failover.sh - Simular failover manual

echo "═══════════════════════════════════════════════════════════"
echo "  SIMULACIÓN DE FAILOVER MANUAL - POLLO SANJUANERO"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "1. Estado ANTES del failover:"
echo "─────────────────────────────────────────────────────────"
echo "Conexiones de replicación activas:"
docker exec postgres-primary psql -U admin -d sanjuanero_db -c \
  "SELECT application_name, state, sync_state FROM pg_stat_replication;"
echo ""

echo "Total de registros en el primario:"
docker exec postgres-primary psql -U admin -d sanjuanero_db -c \
  "SELECT COUNT(*) as total_registros FROM test_replication;"
echo ""

echo "Últimos 3 registros:"
docker exec postgres-primary psql -U admin -d sanjuanero_db -c \
  "SELECT id, mensaje FROM test_replication ORDER BY id DESC LIMIT 3;"
echo ""

echo "2. Simulando caída del servidor primario..."
echo "─────────────────────────────────────────────────────────"
docker-compose stop postgres-primary
echo "✓ Primario DETENIDO (simulando falla crítica)"
echo ""

sleep 3

echo "3. Promoviendo STANDBY a PRIMARIO..."
echo "─────────────────────────────────────────────────────────"

# Método 1: Intentar con pg_ctl
docker exec -u postgres postgres-standby bash -c "pg_ctl promote -D /var/lib/postgresql/data" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Método pg_ctl falló, usando método alternativo..."
  # Método 2: Eliminar standby.signal manualmente
  docker exec -u postgres postgres-standby bash -c "rm -f /var/lib/postgresql/data/standby.signal"
  docker exec postgres-standby bash -c "kill -HUP 1"
fi

echo ""
echo "Esperando que el standby asuma el rol de primario..."
sleep 8

# Verificar que se promovió
if docker exec postgres-standby test -f /var/lib/postgresql/data/standby.signal 2>/dev/null; then
  echo "⚠ Intentando promoción alternativa..."
  docker exec postgres-standby rm -f /var/lib/postgresql/data/standby.signal
  docker restart postgres-standby
  sleep 10
  echo "✓ Standby reiniciado como primario"
else
  echo "✓ Standby promovido exitosamente a PRIMARIO"
fi
echo ""

echo "4. Verificando que el NUEVO PRIMARIO acepta escrituras:"
echo "─────────────────────────────────────────────────────────"
TIMESTAMP=$(date +%H:%M:%S)
docker exec postgres-standby psql -U admin -d sanjuanero_db -c \
  "INSERT INTO test_replication (mensaje) VALUES ('✓ Escrito en NUEVO primario post-failover - $TIMESTAMP');"

if [ $? -eq 0 ]; then
  echo "✓ El nuevo primario ACEPTA ESCRITURAS correctamente"
else
  echo "✗ ERROR: El nuevo primario aún está en modo lectura"
  echo ""
  echo "Intentando forzar la promoción..."
  docker exec postgres-standby rm -f /var/lib/postgresql/data/standby.signal
  docker restart postgres-standby
  sleep 10

  echo "Reintentando escritura..."
  docker exec postgres-standby psql -U admin -d sanjuanero_db -c \
    "INSERT INTO test_replication (mensaje) VALUES ('✓ Escrito tras reinicio - $TIMESTAMP');"

  if [ $? -eq 0 ]; then
    echo "✓ El nuevo primario ahora ACEPTA ESCRITURAS"
  else
    echo "✗ La promoción requiere intervención manual"
  fi
fi
echo ""

echo "5. Datos en el NUEVO PRIMARIO después del failover:"
echo "─────────────────────────────────────────────────────────"
docker exec postgres-standby psql -U admin -d sanjuanero_db -c \
  "SELECT id, mensaje FROM test_replication ORDER BY id DESC LIMIT 5;"
echo ""

echo "6. Estado de la RÉPLICA DE LECTURA:"
echo "─────────────────────────────────────────────────────────"
echo "(La réplica mantiene los datos pero puede perder conexión)"
docker exec postgres-replica-readonly psql -U admin -d sanjuanero_db -c \
  "SELECT COUNT(*) as total_registros FROM test_replication;" 2>&1 | head -10
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  RESULTADO DEL FAILOVER"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📊 Estado Final:"
echo "  • Primario original (postgres-primary): ⛔ DETENIDO"
echo "  • Standby (postgres-standby): ✓ Ahora es el NUEVO PRIMARIO"

# Verificar si realmente acepta escrituras
docker exec postgres-standby psql -U admin -d sanjuanero_db -c "SELECT 1" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  docker exec postgres-standby psql -U admin -d sanjuanero_db -c \
    "INSERT INTO test_replication (mensaje) VALUES ('test')" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "  • Nuevo primario acepta escrituras: ✓ SÍ"
    docker exec postgres-standby psql -U admin -d sanjuanero_db -c \
      "DELETE FROM test_replication WHERE mensaje = 'test'" > /dev/null 2>&1
  else
    echo "  • Nuevo primario acepta escrituras: ✗ NO (aún en modo lectura)"
  fi
fi

echo "  • Réplica de lectura: ⚠ Puede necesitar reconfiguración"
echo ""