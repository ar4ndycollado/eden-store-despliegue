#!/bin/bash
# Respaldo diario del esquema SISTEMA_VENTAS con Data Pump.
# Instalar:  sudo cp respaldo_oracle.sh /usr/local/bin/ && sudo chmod 750 /usr/local/bin/respaldo_oracle.sh
# Programar: sudo crontab -e   ->   0 2 * * * /usr/local/bin/respaldo_oracle.sh
set -e

FECHA=$(date +%Y%m%d_%H%M)
CARPETA=/opt/oracle-xe/respaldos
DIAS_A_GUARDAR=7
source /opt/eden-store/.env      # trae DB_PASSWORD

docker exec oracle-xe expdp "sistema_ventas/${DB_PASSWORD}@localhost:1521/XEPDB1" \
    SCHEMAS=sistema_ventas DIRECTORY=DIR_RESPALDOS \
    DUMPFILE=sistema_ventas_${FECHA}.dmp LOGFILE=exp_${FECHA}.log

# Borrar respaldos con más de 7 días
find "$CARPETA" -name "*.dmp" -mtime +$DIAS_A_GUARDAR -delete
find "$CARPETA" -name "*.log" -mtime +$DIAS_A_GUARDAR -delete

echo "$(date) Respaldo OK: sistema_ventas_${FECHA}.dmp" >> /var/log/respaldo_oracle.log
