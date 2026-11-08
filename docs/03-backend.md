Backend— aplicación Flask en
producción
Responsable: Debora Raquel Tzoy Zapeta
Estructura de la aplicación
La aplicación Eden Store está hecha en Python 3.12 + Flask con el patrón
Modelo-Vista-Controlador:
Carpeta Contenido
models/ Consultas SQL a Oracle (
python-oracledb)
controllers/ Lógica de cada pantalla (Flask
Blueprints)
templates/ Páginas HTML (Jinja2)
app.py Inicio, registro de módulos y control
de acceso
Antes de cada petición, app.py verifica que exista una sesión y que el rol del
usuario tenga permiso para el módulo ( before_request).
Configuración por variables de entorno
En el servidor, las credenciales no están en el código. El archivo config.py
las lee de variables de entorno:
DB_PASSWORD = os.environ["DB_PASSWORD"]
SECRET_KEY = os.environ["SECRET_KEY"]
Esas variables están en /opt/eden-store/.env (permisos 600, dueño edenapp
), y systemd las carga al iniciar el servicio con EnvironmentFile=. La
SECRET_KEY, que firma las sesiones, se generó al azar:
python3 -c "import secrets; print(secrets.token_hex(32))"
Ejecución con Gunicorn
Flask no se ejecuta con python app.py en producción, sino con Gunicorn, un
servidor de aplicación con 3 procesos (workers) que atiende varias peticiones
a la vez:
gunicorn --workers 3 --bind 127.0.0.1:8000 app:app
Las librerías se instalaron en un entorno virtual aislado: /opt/eden-store/venv.
Conexión con Oracle
La aplicación se conecta a localhost:1521/xepdb1 con el usuario
sistema_ventas. Se probó el login completo contra la base de datos antes de
publicar:
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/login
Respuesta 200 = la página carga; un POST de login correcto responde 302
(redirección al dashboard).
Seguridad de los usuarios de la aplicación
Las contraseñas de prueba eran públicas en el repositorio. En producción se
renombraron los usuarios según su rol (administrador, cajero, vendedor,
bodeguero) y se les asignaron contraseñas aleatorias, guardadas con hash
scrypt.
