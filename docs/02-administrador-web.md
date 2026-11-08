# Administración Web — Nginx, servicios y HTTPS

Responsable: Carlos Francisco Contreras Morales

## Qué se configuró
El servidor web es **Nginx 1.24**, que funciona como *proxy inverso*: recibe las peticiones de Internet
y se las pasa a **Gunicorn**, que ejecuta la aplicación Flask en `127.0.0.1:8000`. Gunicorn nunca queda
expuesto a Internet; solo Nginx.

```
Internet → Nginx (80/443) → Gunicorn 127.0.0.1:8000 → Flask → Oracle
```

## Server block de Nginx
Archivo: `/etc/nginx/sites-available/eden-store` (enlazado en `sites-enabled`).

- `server_name`: dominio de Azure `eden-store-ar4ndyc.brazilsouth.cloudapp.azure.com` y la IP pública.
- `location /static/`: Nginx entrega directamente los archivos CSS, sin pasar por Flask.
- `location /`: `proxy_pass http://127.0.0.1:8000` con las cabeceras `Host`, `X-Real-IP` y `X-Forwarded-For`.
- Se eliminó el sitio `default` de Nginx.

Antes de aplicar cualquier cambio se valida la sintaxis:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## La aplicación como servicio de systemd
Archivo: `/etc/systemd/system/eden-store.service`

- Se ejecuta con el usuario `edenapp` (no root).
- Carga las variables del archivo `/opt/eden-store/.env`.
- Inicia Gunicorn con 3 procesos: `gunicorn --workers 3 --bind 127.0.0.1:8000 app:app`.
- `Restart=always`: si se cae, systemd lo vuelve a levantar.
- Depende de `oracle-xe.service`, así que arranca después de la base de datos.

```bash
sudo systemctl enable --now eden-store
systemctl status eden-store
```

## HTTPS con Let's Encrypt
Se usó el nombre DNS gratuito de Azure como dominio y **certbot** para obtener el certificado:
```bash
sudo certbot --nginx -d eden-store-ar4ndyc.brazilsouth.cloudapp.azure.com
sudo certbot renew --dry-run
```
Certbot agregó el bloque de HTTPS (puerto 443) y la redirección automática de HTTP a HTTPS.
El certificado se renueva solo con el temporizador `certbot.timer`.

## Problema resuelto
Desde el celular la página daba «conexión rechazada»: el navegador forzaba HTTPS y todavía no había
certificado. Al instalarlo con certbot, la página funcionó en todos los dispositivos.

## Comandos que explico en el video
| Comando | Para qué sirve |
|---|---|
| `systemctl status nginx eden-store` | Ver si los servicios están activos y habilitados al arranque |
| `sudo systemctl restart eden-store` | Reiniciar la aplicación después de un cambio |
| `sudo ss -tlnp` | Ver los puertos abiertos: 22, 80 y 443 públicos; 8000 y 1521 solo en 127.0.0.1 |
| `journalctl -u eden-store -n 20` | Ver los últimos 20 registros de la aplicación (peticiones y errores) |
| `sudo nginx -t` | Validar la configuración de Nginx antes de recargarla |
