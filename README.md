# Despliegue de Eden Store en un VPS Linux

Proyecto integrador de **Sistemas Operativos**: configuración, seguridad y despliegue en producción
de una aplicación web en **Ubuntu Server 24.04 LTS** sobre un VPS de **Microsoft Azure**.

🌐 **Aplicación publicada:** <https://eden-store-ar4ndyc.brazilsouth.cloudapp.azure.com>

La aplicación desplegada es *Eden Store*, un sistema de ventas en Flask + Oracle
(repositorio aparte: [ar4ndycollado/sistema_ventas](https://github.com/ar4ndycollado/sistema_ventas)).
Este repositorio contiene **todo lo necesario para montar el servidor**: configuración, servicios,
scripts y la guía paso a paso.

## Arquitectura

```
Internet ──HTTPS──► Azure NSG (22, 80, 443) ──► UFW ──► Nginx :443
                                                          │ proxy
                                                          ▼
                                            Gunicorn 127.0.0.1:8000 (Flask)
                                                          │
                                                          ▼
                                     Docker: Oracle 21c XE 127.0.0.1:1521/XEPDB1
```

| Componente | Tecnología | Servicio systemd |
|---|---|---|
| Sistema operativo | Ubuntu Server 24.04 LTS (Azure, Standard_D2as_v4: 2 vCPU, 8 GB) | — |
| Acceso remoto | OpenSSH con llave ed25519, sin root ni contraseña, fail2ban | `ssh`, `fail2ban` |
| Firewall | UFW + grupo de seguridad de red de Azure | `ufw` |
| Servidor web | Nginx (proxy inverso) + Let's Encrypt (certbot) | `nginx` |
| Aplicación | Python 3.12, Flask, Gunicorn (usuario `edenapp`) | `eden-store` |
| Base de datos | Oracle Database 21c XE en Docker | `docker`, `oracle-xe` |
| Respaldos | Data Pump (`expdp`) + cron | `cron` |

## Estructura

```
despliegue/
├── GUIA_DESPLIEGUE.md     guía completa, paso a paso, con capturas sugeridas
├── oracle/                docker-compose.yml y scripts SQL (esquema, roles, permisos)
├── app/                   config.py del servidor y plantilla del .env
├── nginx/                 server block de Nginx
├── systemd/               servicios eden-store y oracle-xe
└── scripts/               actualizar.sh, respaldo, restauración y monitoreo
```

## Equipo y roles

| Integrante | Rol | Rama |
|---|---|---|
| _(nombre)_ | 1. Administrador Linux | `feature/nombre-linux` |
| _(nombre)_ | 2. Administrador Web | `feature/nombre-web` |
| _(nombre)_ | 3. Desarrollador Backend | `feature/nombre-backend` |
| _(nombre)_ | 4. Desarrollador Frontend | `feature/nombre-frontend` |
| _(nombre)_ | 5. DevOps y Base de Datos | `feature/nombre-devops` |

## Flujo de trabajo en Git

- `main`: lo que está en producción. **Sin commits directos**, solo Pull Requests desde `develop`.
- `develop`: integración.
- `feature/nombre-rol`: rama de cada integrante, siempre creada desde `develop`.

```bash
git checkout develop && git pull
git checkout -b feature/nombre-rol
# ... cambios, commit, push ...
# Pull Request: feature/nombre-rol → develop   y luego   develop → main
```

## Seguridad

Ningún archivo de este repositorio contiene contraseñas reales. Los valores `CLAVE_BD`, `CLAVE_SYS`
y `pegar_aqui_la_clave_generada` son marcadores: las claves reales viven solo en los archivos `.env`
del servidor (permisos `600`), que nunca se suben a GitHub.
