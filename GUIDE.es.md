# Guía Didáctica: descarga de imagen ISO de Windows

## Resumen

El script `download-windows-iso` automatiza la descarga de un archivo ISO de Windows 11 desde el sitio web de Microsoft. Utiliza una combinación de Bash, Docker y Playwright (una biblioteca de automatización de navegadores) para:

1. Construir una imagen Docker con Playwright instalado.
2. Lanzar un navegador headless para visitar la página de descarga de Windows 11 de Microsoft.
3. Seleccionar la edición deseada del producto (por ejemplo, Windows 11) y el idioma.
4. Extraer el vínculo de descarga directo para el ISO.
5. Usar `wget` para descargar el ISO al directorio local `tmp/`.

## Cómo Funciona

### Paso 1: Construcción de la Imagen Docker

El script comienza construyendo una imagen Docker llamada `download-windows-iso-2026-bindows` usando el `Dockerfile` del proyecto. El `Dockerfile`:

- Parte de la imagen oficial `mcr.microsoft.com/playwright/python:latest`, que incluye Playwright y Chromium.
- Copia `requirements.txt` e instala las dependencias de Python (actualmente `playwright`.
- Ejecuta `playwright install` para descargar el ejecutable del navegador Chromium.
- Copia el directorio local `scripts/` dentro de la imagen.
- Establece el punto de entrada para ejecutar el módulo Python `srv` con el argumento `--language`.

### Paso 2: Ejecutar la Aplicación Python

El script ejecuta `docker compose build` y `docker run` para iniciar el contenedor. El contenedor ejecuta una aplicación Python (`scripts/play.py`) que:

- Lanzamiento de Chromium en modo headless.
- Navega a `https://www.microsoft.com/software-download/windows11`.
- Descarta cualquier banner de consentimiento de cookies si está presente.
- Selecciona la edición del producto (índice 1, típicamente "Windows 11").
- Haz clic en el botón "Submit" para continuar.
- Espera a que el selector de idioma se vuelva visible.
- Selecciona el idioma especificado mediante el argumento `-l` o `--language` (predeterminado: "English International").
- Haz clic en "Submit" nuevamente para proceder a la página de descarga.
- Espera a que aparezca el vínculo de descarga `<a class="product-download-type">`.
- Extrae el atributo `href` (la URL de descarga directa).
- El script Bash captura esta URL desde la salida estándar del contenedor.

### Paso 3: Descargar el ISO

Una vez obtenida la URL de descarga directa, el script Bash:

- Crea el directorio `tmp/` si no existe.
- Cambia al directorio `tmp/`.
- Ejecuta `wget --content-disposition <URL>` para descargar el archivo ISO, preservando el nombre de archivo original.

### Paso 4: Uso

```bash
# Predeterminado: Inglés Internacional
./download.sh

# Especificar un idioma
./download.sh -l "English International"

# Los idiomas disponibles dependen del sitio web de Microsoft; valores comunes incluyen:
# - "English International"
# - "Español"
# - "Français"
# - etc.
```

## Correcciones Recientes

- Agregado `playwright install` al `Dockerfile` para asegurar que el ejecutable de Chromium esté disponible.
- Agregado `wait_for_load_state("networkidle")` después de la navegación de página para asegurar que los recursos estén cargados.
- Agregado lógica de descarte del banner de consentimiento de cookies.
- Agregado esperas explícitas para la visibilidad de elementos para mejorar la fiabilidad.

## Solución de Problemas

Si el script falla:

- Asegúrese de que Docker esté en ejecución y accesible.
- Verifique que el argumento de idioma coincida exactamente con lo que muestra Microsoft (mayúscul/minúscul).
- El script puede fallar si Microsoft cambia el diseño de su sitio web; en ese caso, los selectores de Playwright pueden necesitar actualizarse.