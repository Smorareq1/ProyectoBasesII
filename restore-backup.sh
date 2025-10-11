#!/bin/bash
# restore-backup.sh - Restaurar desde backup

echo "=== RESTAURACIÓN DE BACKUP ==="
echo ""

# Listar backups disponibles
echo "Backups Full disponibles:"
ls -lh ./backups/full/
echo ""

read -p "Ingrese el nombre del archivo de backup a restaurar: " BACKUP_FILE

if [ ! -f "./backups/full/$BACKUP_FILE" ]; then
  echo "ERROR: Archivo no encontrado"
  exit 1
fi

echo ""
echo "ADVERTENCIA: Esto eliminará los datos actuales"
read -p "¿Continuar? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Restauración cancelada"
  exit 0
fi

echo ""
echo "1. Deteniendo el primario..."
docker-compose stop postgres-primary

echo "2. Eliminando datos actuales..."
docker volume rm proyectobases_primary_data

echo "3. Creando nuevo volumen..."
docker volume create proyectobases_primary_data

echo "4. Restaurando backup..."
# Esto requiere un contenedor temporal para descomprimir
docker run --rm \
  -v proyectobases_primary_data:/var/lib/postgresql/data \
  -v "$(pwd)/backups/full:/backup" \
  postgres:15 \
  bash -c "cd /var/lib/postgresql/data && tar -xzf /backup/$BACKUP_FILE"

echo "5. Reiniciando el primario..."
docker-compose up -d postgres-primary

echo ""
echo "✓ Restauración completada"
echo "Esperando a que el servidor inicie..."
sleep 10

docker exec postgres-primary psql -U admin -d sanjuanero_db -c "SELECT COUNT(*) as total_registros FROM test_replication;"