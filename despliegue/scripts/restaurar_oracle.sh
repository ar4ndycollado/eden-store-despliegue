#!/bin/bash
# Restaura un respaldo en un esquema de PRUEBA (no toca el original).
# Uso: sudo ./restaurar_oracle.sh sistema_ventas_20261028_0200.dmp
set -e
ARCHIVO=$1
if [ -z "$ARCHIVO" ]; then
    echo "Uso: $0 <archivo.dmp>"
    ls /opt/oracle-xe/respaldos
    exit 1
fi
source /opt/oracle-xe/.env       # trae ORACLE_PASSWORD

docker exec oracle-xe impdp "system/${ORACLE_PASSWORD}@localhost:1521/XEPDB1" \
    DIRECTORY=DIR_RESPALDOS DUMPFILE=$ARCHIVO LOGFILE=imp_prueba.log \
    REMAP_SCHEMA=sistema_ventas:sistema_ventas_rest EXCLUDE=PROCOBJ

echo "Restaurado en el esquema SISTEMA_VENTAS_REST"
