# Frontend — interfaz publicada y diseño responsive

Responsable: Beatriz Alejandra Us Cos

## Interfaz
La interfaz está hecha con **HTML (plantillas Jinja2), CSS propio y JavaScript**, sin frameworks.
Los colores se definen como variables en `:root` dentro de `static/css/estilos.css`.

En producción, Nginx entrega los archivos de `/static/` directamente (sin pasar por Flask), con caché de 7 días, lo que hace que la página cargue más rápido.

## Problema encontrado: vista de escritorio en el celular
Al abrir la aplicación publicada en el celular, la página se veía como una versión de escritorio reducida. La etiqueta `viewport` sí existía, pero el CSS **no tenía ninguna regla `@media`**: el menú lateral medía 220 px fijos y las tablas eran más anchas que la pantalla, así que el navegador achicaba toda la página.

## Solución: sección responsive en estilos.css
Para pantallas de hasta 768 px de ancho:

| Elemento | Cambio |
|---|---|
| Menú lateral | Pasa a la parte de arriba; los enlaces quedan en una fila que se desliza con el dedo |
| Contenido | `min-width: 0` para que pueda encogerse |
| Tablas anchas | Se desplazan dentro de su tarjeta, sin achicar la página |
| Formularios | Una sola columna |
| Encabezados, filtros y botones | Se acomodan en varias líneas |

```css
@media (max-width: 768px) {
    body { flex-direction: column; }
    .menu { width: 100%; border-right: none; border-bottom: 1px solid var(--borde); }
    .menu nav { display: flex; overflow-x: auto; }
    .fila-campos, .opciones-check { grid-template-columns: 1fr; }
}
```

## Pruebas
- PC: Chrome con la URL pública y HTTPS.
- Celular: con datos móviles (fuera de la red local) para comprobar el acceso desde Internet.
- Se probaron login, dashboard, lista de clientes y el formulario de nuevo cliente.
- Para ver cambios de CSS en el celular se usa una pestaña de incógnito (por la caché de 7 días).


  ## Comandos que explico en el video

| Comando | Para qué sirve |
|---|---|
| `sudo find /opt/eden-store/app -name "*.css"` | Buscar archivos por nombre: encuentra la hoja de estilos |
| `sudo nano /opt/eden-store/app/static/css/estilos.css` | Abrir un archivo en el editor de la terminal (guardar Ctrl+O, salir Ctrl+X) |
| `sudo cp origen destino` | Copiar archivos; así se instalaron los scripts en /usr/local/bin |
