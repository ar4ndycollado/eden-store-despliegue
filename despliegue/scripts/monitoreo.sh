#!/bin/bash
# Muestra el estado del servidor y de los servicios (útil para el video y las capturas).
echo "===== $(hostname) - $(date) ====="
echo; echo "--- Uptime y carga ---";   uptime
echo; echo "--- Memoria ---";          free -h
echo; echo "--- Disco ---";            df -h /
echo; echo "--- Servicios ---"
for s in ssh nginx docker oracle-xe eden-store; do
    printf "%-12s %s\n" "$s" "$(systemctl is-active $s)"
done
echo; echo "--- Puertos escuchando ---"
ss -tln | grep -E ':22 |:80 |:443 |:1521 |:8000 '
echo; echo "--- Firewall ---"
sudo ufw status
echo; echo "--- Contenedor Oracle ---"
docker ps --filter name=oracle-xe --format "{{.Names}}  {{.Status}}"
