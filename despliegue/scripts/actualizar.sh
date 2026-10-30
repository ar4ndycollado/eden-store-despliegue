#!/bin/bash
# Despliegue: trae la última versión de la rama main desde GitHub y reinicia la app.
# Instalar:  sudo cp actualizar.sh /usr/local/bin/ && sudo chmod 750 /usr/local/bin/actualizar.sh
# Usar:      sudo actualizar.sh
set -e

APP=/opt/eden-store/app
VENV=/opt/eden-store/venv
RAMA=main
LOG=/var/log/eden-store-deploy.log

if [ "$EUID" -ne 0 ]; then
    echo "Ejecutar con sudo:  sudo actualizar.sh"
    exit 1
fi

# Todos los comandos de git se ejecutan como edenapp, el dueño de la aplicación
GIT="sudo -u edenapp git -C $APP"

echo "== Actualizando Eden Store desde la rama $RAMA =="

# 1. Revisar que no haya cambios hechos a mano en el servidor
if [ -n "$($GIT status --porcelain --untracked-files=no)" ]; then
    echo "ERROR: hay archivos modificados a mano en el servidor:"
    $GIT status --short --untracked-files=no
    echo "Revíselos; para descartarlos:  sudo -u edenapp git -C $APP checkout -- ."
    exit 1
fi

# 2. Descargar los cambios de GitHub
ANTES=$($GIT rev-parse HEAD)
$GIT fetch origin $RAMA
$GIT checkout -q $RAMA
$GIT merge --ff-only origin/$RAMA
DESPUES=$($GIT rev-parse HEAD)

if [ "$ANTES" = "$DESPUES" ]; then
    echo "Ya estaba actualizado (commit ${DESPUES:0:7}). No se reinicia nada."
    exit 0
fi

echo
echo "Commits nuevos:"
$GIT log --oneline "$ANTES..$DESPUES"
echo
echo "Archivos cambiados:"
$GIT diff --name-only "$ANTES" "$DESPUES"

# 3. Si cambiaron las librerías, instalarlas
if $GIT diff --name-only "$ANTES" "$DESPUES" | grep -q "^requirements.txt$"; then
    echo
    echo "requirements.txt cambió: instalando librerías..."
    sudo -u edenapp "$VENV/bin/pip" install -q -r "$APP/requirements.txt" gunicorn
fi

# 4. Reiniciar la aplicación y verificar que responde
echo
echo "Reiniciando eden-store..."
systemctl restart eden-store
sleep 3

CODIGO=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/login || true)
if systemctl is-active --quiet eden-store && [ "$CODIGO" = "200" ]; then
    echo "OK: la aplicación responde (HTTP $CODIGO) con el commit ${DESPUES:0:7}"
    echo "$(date '+%F %T') OK ${ANTES:0:7} -> ${DESPUES:0:7}" >> $LOG
else
    echo "ERROR: la aplicación no responde (HTTP $CODIGO). Últimos registros:"
    journalctl -u eden-store -n 20 --no-pager
    echo "Para volver a la versión anterior:"
    echo "  sudo -u edenapp git -C $APP reset --hard ${ANTES:0:7} && sudo systemctl restart eden-store"
    echo "$(date '+%F %T') ERROR ${ANTES:0:7} -> ${DESPUES:0:7} (HTTP $CODIGO)" >> $LOG
    exit 1
fi
