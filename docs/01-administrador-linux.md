# Administración Linux — acceso, usuarios, permisos y firewall

Responsable: Arandy Esduardo Collado Zapeta

## Sistema base
- **Ubuntu Server 24.04.5 LTS** en una VM de Microsoft Azure (Standard_D2as_v4: 2 vCPU, 8 GB de RAM, 30 GB SSD).
- Actualización inicial: `sudo apt update && sudo apt upgrade -y`.
- Zona horaria: `sudo timedatectl set-timezone America/Guatemala`.
- Parches de seguridad automáticos con `unattended-upgrades`.

## Usuarios
| Usuario | Tipo | Uso |
|---|---|---|
| `admin_eden` | Administrador (grupo `sudo`) | Administra el servidor; solo entra con llave SSH |
| `edenapp` | Usuario de sistema, sin contraseña ni shell (`/usr/sbin/nologin`) | Dueño y ejecutor de la aplicación |

```bash
sudo adduser --system --group --home /opt/eden-store --shell /usr/sbin/nologin edenapp
sudo usermod -aG www-data edenapp
```

`edenapp` pertenece al grupo `www-data` para que Nginx pueda leer los archivos estáticos.

## Permisos
| Ruta | Dueño | Permisos | Por qué |
|---|---|---|---|
| `/opt/eden-store` | `edenapp:www-data` | `750` | Solo el dueño y su grupo pueden entrar |
| `/opt/eden-store/.env` | `edenapp` | `600` | Contiene credenciales: solo su dueño lo lee |
| `/opt/oracle-xe/.env` | `root` | `600` | Contraseña de SYS de Oracle |
| `/opt/oracle-xe/respaldos` | `54321` | `755` | UID del usuario `oracle` dentro del contenedor |

`750` = dueño: leer, escribir y entrar (4+2+1); grupo: leer y entrar (4+1); otros: nada (0).

## SSH seguro (hardening)
Archivo `/etc/ssh/sshd_config.d/01-hardening.conf`:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowUsers admin_eden
```

Se nombró `01-` porque SSH aplica el **primer** valor que lee, y Azure trae su propio archivo
`50-cloudimg-settings.conf`. La configuración activa se verifica con `sudo sshd -T`.

## fail2ban
Bloquea durante una hora las IPs que fallan 3 veces. En Ubuntu 24.04 el servicio se llama `ssh.service`
(no `sshd.service`), por eso se ajustó `/etc/fail2ban/jail.local`:

```
[sshd]
enabled = true
backend = systemd
journalmatch = _SYSTEMD_UNIT=ssh.service
maxretry = 3
bantime = 1h
```

## Firewall: dos capas
1. **Grupo de seguridad de red de Azure**: solo permite 22, 80 y 443.
2. **UFW** dentro del servidor:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH          # siempre antes de "enable"
sudo ufw allow 80,443/tcp
sudo ufw enable
```
