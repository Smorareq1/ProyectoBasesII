#!/bin/bash
# fix-scripts.sh - Script para corregir los archivos de inicialización

set -e

echo "=== Fixing PostgreSQL initialization scripts ==="

# Verificar que estamos en el directorio correcto
if [ ! -d "postgres_scripts" ]; then
    echo "ERROR: No se encuentra el directorio postgres_scripts"
    echo "Asegúrate de ejecutar este script desde la raíz del proyecto"
    exit 1
fi

# Convertir line endings a Unix (LF) en caso de que tengan Windows (CRLF)
echo "Converting line endings to Unix format..."

if [ -f "postgres_scripts/primary/00_init.sh" ]; then
    dos2unix postgres_scripts/primary/00_init.sh 2>/dev/null || sed -i 's/\r$//' postgres_scripts/primary/00_init.sh
    echo "✓ Fixed 00_init.sh"
fi

if [ -f "postgres_scripts/primary/init-primary.sh" ]; then
    dos2unix postgres_scripts/primary/init-primary.sh 2>/dev/null || sed -i 's/\r$//' postgres_scripts/primary/init-primary.sh
    echo "✓ Fixed init-primary.sh"
fi

if [ -f "postgres_scripts/replica/entrypoint.sh" ]; then
    dos2unix postgres_scripts/replica/entrypoint.sh 2>/dev/null || sed -i 's/\r$//' postgres_scripts/replica/entrypoint.sh
    echo "✓ Fixed entrypoint.sh"
fi

# Dar permisos de ejecución
echo "Setting executable permissions..."
chmod +x postgres_scripts/primary/00_init.sh 2>/dev/null || true
chmod +x postgres_scripts/primary/init-primary.sh 2>/dev/null || true
chmod +x postgres_scripts/replica/entrypoint.sh 2>/dev/null || true

echo ""
echo "✓ All scripts fixed!"
echo ""
echo "Now run:"
echo "  docker-compose down -v"
echo "  docker-compose up -d"