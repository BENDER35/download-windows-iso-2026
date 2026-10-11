# Descarga de imagen ISO de Windows

Guion bash para descargar la imagen ISO de Windows desde el sitio web de Microsoft usando Docker y Playwright.

## Requisitos

1. Tener `docker`
2. Tener `bash`
3. Tener `wget`

## Uso

### Paso 1

```
# Predeterminado a `Inglés Internacional`
./download.sh [-l IDIOMA]
```

### Paso 2

Verifique `./tmp/` para la ISO descargada.

### Paso 3

El script realizará las siguientes acciones:

1. Construirá una imagen Docker con Playwright instalado
2. Ejecutará un navegador para navegar a la página de descarga de Windows 11 de Microsoft
3. Seleccionará la edición del producto y el idioma
4. Extraerá el vínculo de descarga directo
5. Usará `wget` para descargar la ISO al directorio `tmp/`