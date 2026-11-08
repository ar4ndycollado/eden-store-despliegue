# DevOps y Base de Datos — Oracle, respaldos y despliegue

Responsable: Tomás Enrique Ordóñez Yat

## Oracle 21c XE en Docker
Oracle no tiene instalador para Ubuntu, así que se ejecuta en un contenedor Docker con la imagen
`gvenzl/oracle-xe:21-slim` (ver `despliegue/oracle/docker-compose.yml`).

- Los datos se guardan en un **volumen** (`oracle-datos`), así no se pierden al reiniciar.
- El puerto se publica como `127.0.0.1:1521:1521`. Docker crea sus propias reglas de red y puede
  saltarse UFW, por eso el puerto solo escucha en la máquina: **la base de datos no es accesible
  desde Internet**.
- La contraseña de SYS está en `/opt/oracle-xe/.env` con permisos `600`.
- El servicio `oracle-xe.service` de systemd levanta el contenedor al encender el servidor.

## Carga de la base de datos
1. `01_crear_esquema.sql` (como SYSDBA): usuario `SISTEMA_VENTAS`, roles y directorio de respaldos.
2. Script del proyecto (como `SISTEMA_VENTAS`): 20 tablas, vistas, procedimientos, triggers y datos.
3. `03_grants.sql` (como SYSDBA): permisos por rol y usuarios de base de datos.

Para administrarla se usa un **túnel SSH**: `ssh -N -L 1522:127.0.0.1:1521 admin_eden@<IP>`, y
SQL Developer se conecta a `localhost:1522`.

## Respaldos y restauración
- `respaldo_oracle.sh`: exporta el esquema con Data Pump (`expdp`) y borra respaldos de más de 7 días.
- Programado con cron todos los días a las 2:00 a. m.: `0 2 * * * /usr/local/bin/respaldo_oracle.sh`
- `restaurar_oracle.sh`: restaura el respaldo en un esquema aparte (`SISTEMA_VENTAS_REST`) y compara
  tablas y registros con el original. Resultado: 20 tablas, 16 ventas y 12 productos en ambos.

## Despliegue continuo
`actualizar.sh` publica una nueva versión de la aplicación con un solo comando:
1. Verifica que nadie haya modificado archivos a mano en el servidor.
2. Descarga la rama `main` desde GitHub.
3. Si cambió `requirements.txt`, instala las librerías.
4. Reinicia `eden-store` y comprueba que responda HTTP 200.
5. Registra el despliegue en `/var/log/eden-store-deploy.log`.

## Comandos que explico en el video
| Comando | Para qué sirve |
|---|---|
| `free -h` | Memoria RAM: 8 GB en total; Oracle es lo que más consume |
| `df -h` | Espacio en disco: 30 GB, cerca del 29 % usado |
| `htop` | Procesos en tiempo real con barras de CPU y memoria (salir con F10) |
| `docker ps` | Contenedores en ejecución: oracle-xe debe aparecer como healthy |
| `sudo crontab -l` | Tareas programadas: el respaldo diario |
