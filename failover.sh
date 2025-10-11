#!/bin/bash

echo "=== SIMULACIÓN DE FAILOVER ==="
echo ""

echo "1. Estado ANTES del failover:"
docker exec postgres-primary psql -U admin -d sanjuanero_db -c "SELECT application_name, state FROM pg_stat_replication;"
echo ""

echo "2. Simulando caída del primario..."
docker-compose stop postgres-primary
echo "✓ Primario detenido"
echo ""

sleep 5

echo "3. Promoviendo STANDBY a PRIMARIO..."
docker exec postgres-standby pg_ctl promote -D /var/lib/postgresql/data
echo "✓ Standby promovido"
echo ""

sleep 5

echo "4. Verificando que el nuevo primario acepta escrituras:"
docker exec postgres-standby psql -U admin -d sanjuanero_db -c "INSERT INTO test_replication (mensaje) VALUES ('Escrito en el NUEVO primario post-failover');"
docker exec postgres-standby psql -U admin -d sanjuanero_db -c "SELECT * FROM test_replication ORDER BY id DESC LIMIT 3;"
echo ""

echo "5. Estado de la réplica de lectura:"
docker exec postgres-replica-readonly psql -U admin -d sanjuanero_db -c "SELECT * FROM test_replication ORDER BY id DESC LIMIT 3;"
echo ""

echo "=== FAILOVER COMPLETADO ==="