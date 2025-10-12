# Proyecto de Alta Disponibilidad - Pollo Sanjuanero

## Requisitos Previos
- Docker Desktop instalado y corriendo
- Git Bash o terminal con permisos de ejecución

---

## 1. Iniciar el Proyecto

```bash
# Levantar los 3 nodos (Primario, Standby, Réplica)
docker-compose up -d

# Esperar 30 segundos a que todo inicie
```

---

## 2. Verificar Replicación

```bash
# Verificar que los 3 contenedores estén corriendo
docker-compose ps

# Probar replicación
./test-replication.sh
```

**Resultado esperado:**
- 2 conexiones de replicación activas
- Datos replicados en los 3 nodos
- Réplica rechaza escrituras

---

## 3. Estrategia de Respaldos

### 3.1 Backup Incremental (diario)

```bash
./backup.sh incremental
```

**Qué hace:** Copia archivos WAL (solo cambios)

### 3.2 Full Backup (semanal)

```bash
./backup.sh full
```

**Qué hace:** Copia completa de la base de datos

### 3.3 Simulación de Semana Completa

```bash
./test-backup-strategy.sh
```

**Qué hace:** 
- 6 backups incrementales (Lun-Sáb)
- 1 full backup (Domingo)
- Muestra resumen completo

### 3.4 Ver Backups Creados

```bash
# Ver full backups
ls -lh backups/full/

# Ver backups incrementales
ls -lh backups/incremental/

# Ver espacio usado
du -sh backups/
```

---

## 4. Failover Manual

```bash
# Ejecutar failover (simula caída del primario)
./failover.sh
```

**Qué hace:**
1. Detiene el primario
2. Promueve el standby a primario
3. Verifica que acepta escrituras

---

## 5. Reiniciar Todo (después del failover)

```bash
# Detener todo y limpiar
docker-compose down -v

# Levantar de nuevo
docker-compose up -d
```

---

## Estructura de Archivos

```
ProyectoBases/
├── docker-compose.yml          # Define los 3 nodos
├── .env                        # Variables de configuración
├── test-replication.sh         # Verifica replicación
├── backup.sh                   # Ejecuta backups
├── test-backup-strategy.sh     # Simula semana de backups
├── failover.sh                 # Simula failover manual
└── backups/                    # Carpeta de backups
    ├── full/                   # Full backups semanales
    └── incremental/            # Backups incrementales diarios
```

---

## Comandos Útiles

```bash
# Ver logs de un contenedor
docker-compose logs postgres-primary
docker-compose logs postgres-standby
docker-compose logs postgres-replica-readonly

# Ver logs en tiempo real
docker-compose logs -f

# Conectarse a la base de datos
docker exec -it postgres-primary psql -U admin -d sanjuanero_db

# Ver estado de replicación
docker exec postgres-primary psql -U admin -d sanjuanero_db -c "SELECT * FROM pg_stat_replication;"

# Insertar datos de prueba
docker exec postgres-primary psql -U admin -d sanjuanero_db -c "INSERT INTO test_replication (mensaje) VALUES ('Prueba manual');"
```

---

## Troubleshooting
### Si el primario no acepta conexiones:
```bash
docker-compose restart postgres-primary
```