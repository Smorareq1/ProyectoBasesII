#!/bin/bash
# test-replication.sh

echo "=== TEST DE REPLICACIÓN POSTGRESQL ==="
echo ""

echo "1. Estado de contenedores:"
docker-compose ps
echo ""

echo "2. Verificando estado de replicación en el primario:"
docker exec -it postgres-primary psql -U admin -d sanjuanero_db -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
echo ""

echo "3. Insertando dato de prueba en el primario:"
docker exec -it postgres-primary psql -U admin -d sanjuanero_db -c "INSERT INTO test_replication (mensaje) VALUES ('Test $(date +%H:%M:%S)');"
echo ""

echo "4. Datos en el PRIMARIO:"
docker exec -it postgres-primary psql -U admin -d sanjuanero_db -c "SELECT * FROM test_replication ORDER BY id DESC LIMIT 5;"
echo ""

echo "5. Datos en el STANDBY:"
docker exec -it postgres-standby psql -U admin -d sanjuanero_db -c "SELECT * FROM test_replication ORDER BY id DESC LIMIT 5;"
echo ""

echo "6. Datos en la RÉPLICA DE LECTURA:"
docker exec -it postgres-replica-readonly psql -U admin -d sanjuanero_db -c "SELECT * FROM test_replication ORDER BY id DESC LIMIT 5;"
echo ""

echo "7. Probando escritura en réplica (debería fallar):"
docker exec -it postgres-replica-readonly psql -U admin -d sanjuanero_db -c "INSERT INTO test_replication (mensaje) VALUES ('Esto debe fallar');" 2>&1 | grep -i "error"
echo ""

echo "=== FIN DEL TEST ==="