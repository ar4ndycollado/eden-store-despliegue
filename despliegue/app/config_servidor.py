# config.py para el SERVIDOR (se copia como /opt/eden-store/app/config.py)
# Lee los datos sensibles de variables de entorno (archivo .env que carga systemd).
# Así ninguna contraseña queda escrita en el código.

import os

DB_USUARIO = os.environ.get("DB_USUARIO", "sistema_ventas")
DB_PASSWORD = os.environ["DB_PASSWORD"]
DB_DSN = os.environ.get("DB_DSN", "localhost:1521/xepdb1")

SECRET_KEY = os.environ["SECRET_KEY"]

NEGOCIO = {
    "nombre": os.environ.get("NEGOCIO_NOMBRE", "Eden Store"),
    "direccion": os.environ.get("NEGOCIO_DIRECCION", "Guatemala"),
    "telefono": os.environ.get("NEGOCIO_TELEFONO", "00000000"),
    "nit": os.environ.get("NEGOCIO_NIT", "0000000-0"),
}

# Contraseñas de prueba (las usa establecer_passwords.py).
# NO se escriben aquí porque este archivo se sube a GitHub.
# Formato en el .env:  PASSWORDS_PRUEBA="usuario1:clave1,usuario2:clave2"
PASSWORDS_PRUEBA = []
for par in os.environ.get("PASSWORDS_PRUEBA", "").split(","):
    if ":" in par:
        usuario, clave = par.split(":", 1)
        PASSWORDS_PRUEBA.append((usuario.strip(), clave.strip()))
