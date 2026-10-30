#!/bin/bash
# Prueba de restauración: carga un respaldo en el esquema SISTEMA_VENTAS_REST
# (el esquema original SISTEMA_VENTAS NO se toca) y compara los datos.
# Uso: sudo restaurar_oracle.sh sistema_ventas_20261031_0200.dmp
set -e

ARCHIVO=$1
CARPETA=/opt/oracle-xe/respaldos

if [ -z "$ARCHIVO" ]; then
    echo "Uso: $0 <archivo.dmp>"
    echo "Respaldos disponibles:"
    ls -lh "$CARPETA"/*.dmp 2>/dev/null || echo "  (ninguno)"
    exit 1
fi
if [ ! -f "$CARPETA/$ARCHIVO" ]; then
    echo "No existe $CARPETA/$ARCHIVO"
    exit 1
fi

source /opt/oracle-xe/.env       # trae ORACLE_PASSWORD
SQL="docker exec -i oracle-xe sqlplus -s / as sysdba"
CLAVE_TEMP="R$(openssl rand -hex 8)"

# 1. Crear (o recrear) el esquema de prueba
echo "== 1. Creando el esquema de prueba SISTEMA_VENTAS_REST =="
$SQL <<EOF
ALTER SESSION SET CONTAINER = XEPDB1;
BEGIN
    EXECUTE IMMEDIATE 'DROP USER sistema_ventas_rest CASCADE';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -1918 THEN RAISE; END IF;   -- -1918: no existía
END;
/
CREATE USER sistema_ventas_rest IDENTIFIED BY "$CLAVE_TEMP"
    DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO sistema_ventas_rest;
EXIT
EOF

# 2. Restaurar el respaldo en el esquema de prueba
echo "== 2. Restaurando $ARCHIVO =="
docker exec oracle-xe impdp "system/${ORACLE_PASSWORD}@localhost:1521/XEPDB1" \
    DIRECTORY=DIR_RESPALDOS DUMPFILE=$ARCHIVO LOGFILE=imp_prueba.log \
    REMAP_SCHEMA=sistema_ventas:sistema_ventas_rest EXCLUDE=PROCOBJ \
    || echo "(impdp terminó con advertencias; revise $CARPETA/imp_prueba.log)"

# 3. Comparar original vs restaurado
echo "== 3. Comparación: original vs restaurado =="
$SQL <<EOF
ALTER SESSION SET CONTAINER = XEPDB1;
SET FEEDBACK OFF
COLUMN esquema FORMAT A22
SELECT owner AS esquema, COUNT(*) AS tablas
FROM dba_tables
WHERE owner IN ('SISTEMA_VENTAS', 'SISTEMA_VENTAS_REST')
GROUP BY owner ORDER BY owner;

SELECT (SELECT COUNT(*) FROM sistema_ventas.ventas)         AS ventas_original,
       (SELECT COUNT(*) FROM sistema_ventas_rest.ventas)    AS ventas_restaurado,
       (SELECT COUNT(*) FROM sistema_ventas.productos)      AS productos_original,
       (SELECT COUNT(*) FROM sistema_ventas_rest.productos) AS productos_restaurado
FROM dual;
EXIT
EOF

echo
echo "Restauración de prueba terminada. Para borrar el esquema de prueba:"
echo '  printf "ALTER SESSION SET CONTAINER=XEPDB1;\nDROP USER sistema_ventas_rest CASCADE;\n" | sudo docker exec -i oracle-xe sqlplus -s / as sysdba'
