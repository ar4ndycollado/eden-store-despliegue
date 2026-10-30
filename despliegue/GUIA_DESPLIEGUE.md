# Guía de despliegue — Eden Store en Ubuntu Server 24.04 (VPS en Azure)

Arquitectura final:

```
 Internet / navegador  →  https://eden-store-xxxx.eastus.cloudapp.azure.com
        │  :80 (HTTP)  /  :443 (HTTPS)
        ▼
 Azure: Grupo de seguridad de red (NSG) — solo 22, 80, 443
        ▼
 ┌────────────────────────── Ubuntu Server 24.04 (VM de Azure, B2s) ───────────────────────┐
 │  UFW (solo 22, 80, 443)                                                                 │
 │                                                                                         │
 │  Nginx  ──proxy──►  Gunicorn 127.0.0.1:8000  ──►  Flask (app.py)                        │
 │  (systemd: nginx)   (systemd: eden-store)              │ python-oracledb                │
 │                                                        ▼                                │
 │                                 Docker: Oracle 21c XE 127.0.0.1:1521/XEPDB1             │
 │                                 (systemd: docker + oracle-xe)                           │
 │  cron 02:00 → respaldo_oracle.sh (Data Pump)  →  /opt/oracle-xe/respaldos               │
 └─────────────────────────────────────────────────────────────────────────────────────────┘
```

Solo Nginx queda expuesto. Gunicorn y Oracle escuchan únicamente en `127.0.0.1`.

---

## 0. Crear el VPS en Azure

### 0.1 Activar Azure for Students
1. Entrar a <https://azure.microsoft.com/free/students> → **Empezar gratis** → iniciar sesión con el **correo de la universidad**.
2. Verificar con el teléfono. **No pide tarjeta.** Recibes USD 100 de crédito.
3. En el portal (<https://portal.azure.com>) buscar **"Suscripciones"**: debe aparecer *Azure for Students*.
4. Alerta de gasto: buscar **"Administración de costos"** → *Presupuestos* → **Agregar** → monto USD 100, alertas al 50 % y 80 % → tu correo.

### 0.2 Crear la llave SSH en Windows (antes de crear la VM)
```powershell
ssh-keygen -t ed25519 -C "admin_eden@eden-server"     # Enter a todo (o pon una frase de paso)
type $env:USERPROFILE\.ssh\id_ed25519.pub              # copiar TODA la línea que imprime
```

### 0.3 Crear la máquina virtual
Portal → **Máquinas virtuales** → **Crear** → *Máquina virtual de Azure*.

**Pestaña Básico**

| Campo | Valor |
|---|---|
| Suscripción | Azure for Students |
| Grupo de recursos | Crear nuevo: `rg-eden-store` |
| Nombre de la máquina | `eden-server` |
| Región | **(US) East US** (si da error de "región no permitida", probar *East US 2*, *South Central US* o *Central US*) |
| Opciones de disponibilidad | No se requiere redundancia de infraestructura |
| Tipo de seguridad | Estándar |
| Imagen | **Ubuntu Server 24.04 LTS – x64 Gen2** |
| Tamaño | **Standard_B2s** (2 vCPU, 4 GB). Si no aparece: *B2als_v2* (2 vCPU, 4 GB). **No** B1s: 1 GB no alcanza para Oracle |
| Tipo de autenticación | **Clave pública SSH** |
| Nombre de usuario | `admin_eden` |
| Origen de clave pública SSH | *Usar clave pública existente* → pegar la línea de `id_ed25519.pub` |
| Puertos de entrada públicos | Permitir: **SSH (22), HTTP (80), HTTPS (443)** |

**Pestaña Discos:** tipo **SSD estándar** (más barato que Premium), 30 GB está bien. Marcar *Eliminar con la VM*.

**Pestaña Redes:** dejar la red e IP pública nuevas. Marcar *Eliminar la IP pública y la NIC cuando se elimine la VM*.

**Pestaña Administración:** activar **Apagado automático** a las 23:00, zona horaria (UTC-06:00) Centroamérica. Ahorra crédito si se te olvida apagarla.

**Revisar y crear** → **Crear**. Tarda 1–2 minutos.

### 0.3-B Lo que funcionó: crear la VM con Azure CLI (Cloud Shell)
El portal no mostraba tamaños válidos: Azure for Students solo permite 5 regiones
(brazilsouth, francecentral, norwayeast, germanywestcentral, canadacentral) y casi todas
las familias tenían cuota 0. La única combinación x64 con cuota fue **Brazil South + Standard_D2as_v4** (2 vCPU, 8 GB).

```bash
LLAVE="ssh-ed25519 AAAA... admin_eden@eden-server"
az group create --name rg-eden-brasil --location brazilsouth
az vm create -g rg-eden-brasil -n eden-server -l brazilsouth \
  --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_D2as_v4 \
  --admin-username admin_eden --ssh-key-values "$LLAVE" \
  --storage-sku StandardSSD_LRS --os-disk-size-gb 30 \
  --public-ip-sku Standard --public-ip-address-dns-name eden-store-ar4ndyc
az vm open-port -g rg-eden-brasil -n eden-server --port 80  --priority 1010
az vm open-port -g rg-eden-brasil -n eden-server --port 443 --priority 1020
az vm auto-shutdown -g rg-eden-brasil -n eden-server --time 0500   # 23:00 Guatemala
```
Resultado: IP `20.226.106.141`, dominio `eden-store-ar4ndyc.brazilsouth.cloudapp.azure.com`.

Encender / apagar (sin cobro de CPU/RAM):
```bash
az vm start      -g rg-eden-brasil -n eden-server
az vm deallocate -g rg-eden-brasil -n eden-server
```

### 0.4 Nombre DNS gratis (sirve como dominio)
VM → **Información general** → *Nombre DNS: No configurado* → poner una etiqueta, ej. `eden-store-tuapellido` → Guardar.
Queda: `eden-store-tuapellido.eastus.cloudapp.azure.com` (sirve para HTTPS en el paso 4).

### 0.5 Conectarse
```powershell
ssh admin_eden@IP_PUBLICA            # la IP está en "Información general" de la VM
```

### 0.6 Memoria swap (recomendado con 4 GB y Oracle)
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h
```

> 📸 Capturas: suscripción Azure for Students, presupuesto, pestaña Básico (imagen y tamaño), reglas de puertos, "Implementación completada", primer `ssh` desde Windows.

---

## 1. Administrador Linux

### 1.1 Actualizar y datos básicos
```bash
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone America/Guatemala
hostnamectl                 # ver nombre y versión
lsb_release -a              # confirmar Ubuntu 24.04
```

### 1.2 Usuarios y permisos
```bash
# admin_eden ya existe (lo creó Azure) y tiene sudo:
id admin_eden

# Usuario de servicio que ejecuta la app (sin login, sin contraseña)
sudo adduser --system --group --home /opt/eden-store --shell /usr/sbin/nologin edenapp
sudo usermod -aG www-data edenapp

# Cuentas para el resto del equipo (opcional, para demostrar gestión de usuarios)
sudo adduser integrante2
sudo usermod -aG sudo integrante2
id admin_eden ; groups edenapp
```

### 1.3 SSH con llave y hardening
La llave de `admin_eden` ya quedó instalada al crear la VM (paso 0.2). Para cada integrante:
cada uno genera su llave en su PC (`ssh-keygen -t ed25519`) y te envía su `.pub`; tú la agregas:
```bash
sudo mkdir -p /home/integrante2/.ssh
sudo nano /home/integrante2/.ssh/authorized_keys      # pegar su llave pública
sudo chown -R integrante2:integrante2 /home/integrante2/.ssh
sudo chmod 700 /home/integrante2/.ssh && sudo chmod 600 /home/integrante2/.ssh/authorized_keys
```
Hardening en el **servidor**:
```bash
sudo nano /etc/ssh/sshd_config.d/01-hardening.conf
```
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
AllowUsers admin_eden integrante2
X11Forwarding no
```
```bash
sudo sshd -t                      # valida la sintaxis (sin salida = OK)
sudo systemctl restart ssh
```
⚠️ Antes de cerrar la sesión, abre **otra** terminal y prueba que puedes entrar. En Azure no hay consola física: si te quedas fuera, usa VM → *Ayuda* → **Restablecer contraseña** → *Restablecer configuración de SSH*.

**Doble firewall en Azure (opcional, buena captura):** VM → *Redes* → regla de SSH (22) → *Origen*: **Mi dirección IP**. Así solo tu IP puede intentar entrar por SSH. Si tu IP cambia, actualiza la regla.

Protección contra fuerza bruta y actualizaciones automáticas:
```bash
sudo apt install -y fail2ban unattended-upgrades
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 1.4 Firewall (UFW)
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH            # 22  ⚠️ SIEMPRE antes de "enable", o pierdes el SSH
sudo ufw allow 80,443/tcp         # HTTP y HTTPS
sudo ufw enable
sudo ufw status verbose
```

> 📸 Capturas: `apt upgrade`, `adduser`/`id`, archivo de hardening, login con llave, `ufw status verbose`, `fail2ban-client status`.

---

## 2. Base de datos (DevOps / BD)

Oracle no tiene instalador para Ubuntu, por eso se ejecuta en **Docker** (imagen `gvenzl/oracle-xe:21-slim`, la misma versión 21c XE que usaste en Windows).

### 2.1 Instalar Docker
```bash
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker admin_eden      # cerrar sesión y volver a entrar
docker --version && docker compose version
```

### 2.2 Copiar los archivos de despliegue al servidor
Desde **Windows (PowerShell)**, en la carpeta `sistemas_operativos`:
```powershell
scp -r despliegue admin_eden@IP_PUBLICA:~/
scp "..\sistema_ventas\database\proyecto_sistema_ventas.sql" admin_eden@IP_PUBLICA:~/despliegue/oracle/
```

### 2.3 Levantar Oracle
```bash
sudo mkdir -p /opt/oracle-xe/sql /opt/oracle-xe/respaldos
sudo cp ~/despliegue/oracle/docker-compose.yml /opt/oracle-xe/
sudo cp ~/despliegue/oracle/*.sql /opt/oracle-xe/sql/
sudo cp ~/despliegue/oracle/env.example /opt/oracle-xe/.env
sudo nano /opt/oracle-xe/.env           # poner una contraseña fuerte para SYS
sudo chmod 600 /opt/oracle-xe/.env
sudo chown 54321:54321 /opt/oracle-xe/respaldos    # 54321 = usuario "oracle" dentro del contenedor

cd /opt/oracle-xe
sudo docker compose up -d
sudo docker logs -f oracle-xe           # esperar "DATABASE IS READY TO USE!" (2-5 min), salir con Ctrl+C
```

### 2.4 Crear el esquema, cargar el script y dar permisos
```bash
# Paso 1 (SYSDBA): usuario SISTEMA_VENTAS, roles y carpeta de respaldos
sudo docker exec -i oracle-xe sqlplus -s / as sysdba @/sql/01_crear_esquema.sql

# Paso 2 (SISTEMA_VENTAS): script principal del proyecto
echo exit | sudo docker exec -i -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 oracle-xe \
  sqlplus -s sistema_ventas/CLAVE_BD@//localhost:1521/XEPDB1 @/sql/proyecto_sistema_ventas.sql \
  > ~/carga_script.log
grep -c "ORA-" ~/carga_script.log     # revisar: algunos ORA- son pruebas intencionales del script (sección 12)

# Paso 3 (SYSDBA): GRANT por rol y usuarios de BD
sudo docker exec -i oracle-xe sqlplus -s / as sysdba @/sql/03_grants.sql

# Verificar
echo "SELECT COUNT(*) FROM user_tables; SELECT usuario FROM usuario;" | \
  sudo docker exec -i oracle-xe sqlplus -s sistema_ventas/CLAVE_BD@//localhost:1521/XEPDB1
```
Debe mostrar **20** tablas y los 5 usuarios de prueba.

> 🔒 `CLAVE_BD` es la contraseña de SISTEMA_VENTAS: la misma en `01_crear_esquema.sql` **y** en `/opt/eden-store/.env`. Nunca suba la real a GitHub.

### 2.5 Oracle como servicio de systemd
```bash
sudo cp ~/despliegue/systemd/oracle-xe.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now oracle-xe
systemctl status oracle-xe
```

> 📸 Capturas: `docker ps`, log "DATABASE IS READY", conteo de tablas, `systemctl status oracle-xe`, `ss -tln` mostrando 1521 solo en 127.0.0.1.

---

## 3. Administrador Web (Nginx + Gunicorn)

### 3.1 Paquetes
```bash
sudo apt install -y nginx python3-venv python3-pip git
```

### 3.2 Código de la aplicación
```bash
sudo git clone https://github.com/ar4ndycollado/sistema_ventas.git /opt/eden-store/app
cd /opt/eden-store

# requirements.txt está en UTF-16 (lo generó PowerShell); convertirlo por si pip falla:
sudo iconv -f UTF-16 -t UTF-8 app/requirements.txt | sudo tee app/requirements.txt.utf8 >/dev/null \
  && sudo mv app/requirements.txt.utf8 app/requirements.txt && sudo sed -i 's/\r$//' app/requirements.txt

sudo python3 -m venv venv
sudo venv/bin/pip install -r app/requirements.txt gunicorn

# Configuración: config.py lee las variables del .env
sudo cp ~/despliegue/app/config_servidor.py app/config.py
sudo cp ~/despliegue/app/env.example .env
python3 -c "import secrets; print(secrets.token_hex(32))"   # copiar el resultado en SECRET_KEY
sudo nano .env

# Permisos: la app pertenece a edenapp; .env solo lo lee edenapp
sudo chown -R edenapp:www-data /opt/eden-store
sudo chmod 750 /opt/eden-store
sudo chmod 600 /opt/eden-store/.env
ls -la /opt/eden-store
```

Prueba manual (Ctrl+C para salir):
```bash
cd /opt/eden-store/app
sudo -u edenapp bash -c 'set -a; source ../.env; set +a; ../venv/bin/gunicorn -b 127.0.0.1:8000 app:app'
# en otra terminal:  curl -I http://127.0.0.1:8000/login
```
Si los usuarios de prueba no pueden entrar:
`sudo -u edenapp bash -c 'set -a; source ../.env; set +a; ../venv/bin/python establecer_passwords.py'`

### 3.3 Gunicorn como servicio
```bash
sudo cp ~/despliegue/systemd/eden-store.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now eden-store
systemctl status eden-store
journalctl -u eden-store -f          # logs en vivo
```

### 3.4 Nginx (server block)
```bash
sudo cp ~/despliegue/nginx/eden-store.conf /etc/nginx/sites-available/eden-store
sudo ln -s /etc/nginx/sites-available/eden-store /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
curl -I http://localhost
```
Abrir desde cualquier lugar: `http://IP_PUBLICA` o `http://eden-store-tuapellido.eastus.cloudapp.azure.com`.

> 📸 Capturas: `pip install`, `ls -la` con permisos, `systemctl status eden-store`, `nginx -t`, login de la app en el navegador, dashboard.

---

## 4. Dominio y HTTPS

1. Poner el nombre DNS de Azure (paso 0.4) en Nginx:
   ```bash
   sudo nano /etc/nginx/sites-available/eden-store
   # server_name eden-store-tuapellido.eastus.cloudapp.azure.com;
   sudo nginx -t && sudo systemctl reload nginx
   ```
2. Certificado gratis de Let's Encrypt (renovación automática incluida):
   ```bash
   sudo apt install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d eden-store-tuapellido.eastus.cloudapp.azure.com
   # correo, aceptar términos; certbot agrega el bloque 443 y la redirección de 80 → 443
   sudo certbot renew --dry-run
   systemctl list-timers | grep certbot
   ```
3. Probar: `https://eden-store-tuapellido.eastus.cloudapp.azure.com` (candado en el navegador).

> Si la IP pública es dinámica, cambia al apagar/desasignar la VM, pero el **nombre DNS se mantiene**: usa siempre el nombre en el documento y el video. Para fijar la IP: recurso *IP pública* → Configuración → **Estática**.

### Control de gastos (importante)
- **Apagar:** portal → VM → **Detener**. Debe quedar *Detenida (desasignada)*; así ya no se cobra la CPU/RAM, solo el disco (~USD 2–3/mes) y la IP.
- **Encender:** VM → **Iniciar**. Los servicios (`oracle-xe`, `eden-store`, `nginx`) arrancan solos por systemd; esperar 2–3 minutos a que Oracle esté listo.
- Revisar el crédito: <https://www.microsoftazuresponsorships.com/Balance> o *Administración de costos*.
- Las semanas de revisión déjala encendida; el resto del tiempo apágala.
- **Al terminar el curso:** borrar el grupo de recursos `rg-eden-store` (elimina VM, disco e IP de una vez).

---

## 5. Respaldos y monitoreo

```bash
sudo cp ~/despliegue/scripts/*.sh /usr/local/bin/
sudo chmod 750 /usr/local/bin/respaldo_oracle.sh /usr/local/bin/restaurar_oracle.sh
sudo chmod 755 /usr/local/bin/monitoreo.sh

sudo /usr/local/bin/respaldo_oracle.sh          # prueba manual
ls -lh /opt/oracle-xe/respaldos

sudo crontab -e                                  # agregar la línea:
# 0 2 * * * /usr/local/bin/respaldo_oracle.sh

sudo /usr/local/bin/restaurar_oracle.sh sistema_ventas_AAAAMMDD_HHMM.dmp   # prueba de restauración
monitoreo.sh                                     # resumen del servidor
```

---

## 6. Git / GitHub (ramas obligatorias)

El repositorio hoy solo tiene `main`. Crear la estructura:
```bash
git checkout -b develop && git push -u origin develop
git checkout -b feature/nombre-linux develop     # cada integrante su rama
# ... commits ...
git push -u origin feature/nombre-linux
# Pull Request: feature/* → develop ; al final develop → main
```
En GitHub: Settings → Branches → regla de protección para `main` (requerir Pull Request).

Sugerencia: copiar la carpeta `despliegue/` al repositorio (ej. `deploy/`) en la rama del DevOps, así el despliegue queda versionado.

**Actualizar producción después de un merge a `main`** (script `scripts/actualizar.sh`):
```bash
sudo cp ~/despliegue/scripts/actualizar.sh /usr/local/bin/
sudo chmod 750 /usr/local/bin/actualizar.sh
sudo actualizar.sh            # pull de main + pip si cambió requirements + reinicio + verificación HTTP 200
cat /var/log/eden-store-deploy.log   # historial de despliegues
```
El script se detiene si encuentra archivos editados a mano en el servidor, y si la app no responde
después de reiniciar muestra los logs y el comando para volver a la versión anterior.

---

## 7. Comandos para la defensa (3 por integrante)

| Integrante | Comandos sugeridos | Ejemplo |
|---|---|---|
| 1 Linux | `chmod`, `chown`, `systemctl` | `ls -la /opt/eden-store`, `sudo systemctl status ssh` |
| 2 Web | `ss`, `curl`, `journalctl` | `ss -tlnp`, `journalctl -u nginx -n 20` |
| 3 Backend | `ps`, `grep`, `cat` | `ps aux \| grep gunicorn`, `cat app.py \| grep register` |
| 4 Frontend | `find`, `ls`, `nano` | `find /opt/eden-store/app/templates -name "*.html"` |
| 5 DevOps/BD | `df`, `free`, `top/htop` | `df -h`, `free -h`, `htop` (Oracle consume RAM) |

Otros: `pwd`, `cd`, `mkdir`, `cp`, `mv`, `rm`, `ip a`, `ping 8.8.8.8`.

---

## 8. Lista de capturas (mínimo 20)

1. Suscripción Azure for Students y creación de la VM (imagen, tamaño B2s) · 2. Reglas de puertos (NSG) · 3. `lsb_release -a`
4. `apt upgrade` · 5. Creación de usuarios / `id` · 6. Archivo de hardening SSH · 7. Login SSH con llave desde Windows
8. `ufw status verbose` · 9. `fail2ban-client status sshd` · 10. `docker ps` · 11. Log de Oracle listo
12. Carga del script / conteo de tablas · 13. `systemctl status oracle-xe` · 14. `pip install` en el venv
15. Permisos `ls -la /opt/eden-store` · 16. `systemctl status eden-store` · 17. `nginx -t` y server block
18. `ss -tln` (puertos) · 19. Login de la app con URL pública · 20. Dashboard · 21. CRUD funcionando
22. Respaldo generado (`ls -lh respaldos`) · 23. `crontab -l` · 24. `monitoreo.sh` · 25. Ramas en GitHub

---

## 9. Problemas comunes

| Problema | Causa / solución |
|---|---|
| `502 Bad Gateway` | Gunicorn caído: `journalctl -u eden-store -n 50` |
| `DPY-6005` / no conecta a Oracle | Oracle aún iniciando (`docker logs oracle-xe`) o contraseña distinta en `.env` |
| `KeyError: 'DB_PASSWORD'` | Falta la variable en `/opt/eden-store/.env` |
| CSS no carga (403) | Nginx (www-data) no puede leer `static/`: `sudo chmod 750 /opt/eden-store` y grupo `www-data` |
| Oracle se reinicia / la VM se congela | Poca RAM: confirmar swap (`free -h`) y tamaño B2s (no B1s) |
| Me quedé fuera por SSH | Portal → VM → *Restablecer contraseña* → *Restablecer configuración de SSH*, o revisar la regla de *Mi dirección IP* en Redes |
| La página no abre desde Internet | Revisar las **dos** capas: reglas de entrada de Azure (Redes) **y** `sudo ufw status` |
| "Región no permitida" al crear la VM | Azure for Students limita regiones: probar East US 2, South Central US o Central US |
| Certbot falla | El nombre DNS debe resolver a la VM (`ping nombre.cloudapp.azure.com`) y el puerto 80 abierto |
| Puerto 1521 visible desde fuera | Verificar `127.0.0.1:1521:1521` en el compose (Docker ignora UFW) |
| Acentos raros en datos | Ejecutar sqlplus con `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` |
