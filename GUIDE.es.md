# Guía Didáctica: descarga de imagen ISO de Windows

## Resumen

El script `download-windows-iso` automatiza la descarga de un archivo ISO de Windows 10 o Windows 11 desde el sitio web de Microsoft. Utiliza una combinación de Bash, Docker y Playwright (una biblioteca de automatización de navegadores) para:

1. Construir una imagen Docker con Playwright instalado.
2. Lanzar un navegador headless para visitar la página de descarga de Windows 10/11 de Microsoft.
3. Seleccionar la edición deseada del producto (por ejemplo, Windows 10 o Windows 11) y el idioma.
4. Extraer el vínculo de descarga directo para el ISO.
5. Usar `wget` para descargar el ISO al directorio local `tmp/`.

## Cómo Funciona

### Paso 1: Construcción de la Imagen Docker

El script comienza construyendo una imagen Docker llamada `download-windows-iso-2026-bindows` usando el `Dockerfile` del proyecto. El `Dockerfile`:

- Parte de la imagen oficial `mcr.microsoft.com/playwright/python:latest`, que incluye Playwright y Chromium.
- Copia `requirements.txt` e instala las dependencias de Python (actualmente `playwright`).
- Ejecuta `playwright install` para descargar el ejecutable del navegador Chromium.
- Copia el directorio local `scripts/` dentro de la imagen.
- Establece el punto de entrada para ejecutar el módulo Python `srv` con los argumentos `--language` y `--windows-version`.

### Paso 2: Ejecutar la Aplicación Python

El script ejecuta `docker compose build` y `docker run` para iniciar el contenedor. El contenedor ejecuta una aplicación Python (`scripts/play.py`) que:

- Lanzamiento de Chromium en modo headless.
- Navega a `https://www.microsoft.com/software-download/windows{10/11}` (depende del argumento `-w`).
- Descarta cualquier banner de consentimiento de cookies si está presente.
- Selecciona la edición del producto según la versión de Windows seleccionada.
- Haz clic en el botón "Submit" para continuar.
- Espera a que el selector de idioma se vuelva visible.
- Selecciona el idioma especificado mediante el argumento `-l` o `--language` (predeterminado: "English International").
- Haz clic en "Submit" nuevamente para proceder a la página de descarga.
- Espera a que aparezca el vínculo de descarga `<a class="product-download-type">`.
- Extrae el atributo `href` (la URL de descarga directa).
- El script Bash captura esta URL desde la salida estándar del contenedor.
- Nota: El sitio web de Microsoft puede requerir completar la descarga manualmente debido a medidas anti-bot.

### Paso 3: Descargar el ISO

Una vez obtenida la URL de la página de descarga directa del script:

- Crea el directorio `tmp/` si no existe.
- Cambia al directorio `tmp/`.
- El usuario puede ejecutar `wget --content-disposition <URL>` para descargar el archivo ISO, preservando el nombre de archivo original.
- Nota: El sitio web de Microsoft puede requerir completar la descarga manualmente debido a medidas anti-bot.

### Paso 4: Uso

```bash
# Predeterminado: Windows 11, Inglés Internacional
./download.sh

# Descargar Windows 10, Inglés Internacional
./download.sh -l "Inglés Internacional" -w 10

# Descargar Windows 11, Español
./download.sh -l "Español" -w 11

# Los idiomas disponibles dependen del sitio web de Microsoft; valores comunes incluyen:
# - "English International"
# - "Español"
# - "Français"
# - etc.
```

### Advertencias Importantes para Windows 10

Al descargar Windows 10:

- **Soporte principal finalizado**: 14 de octubre de 2025
- **ESU (Actualizaciones de Soporte Extendido) finaliza**: 12 de octubre de 2027
  (Programa de pago de 3 años para recibir actualizaciones críticas e importantes de seguridad)
- **Microsoft puede retirar las descargas de ISOS en cualquier momento** - el vínculo de descarga puede volverse sin aviso previo
- Considere usar Windows 11 para recibir actualizaciones de seguridad continuadas y soporte

## Correcciones Recientes

- Agregado `playwright install` al `Dockerfile` para asegurar que el ejecutable de Chromium esté disponible.
- Agregado `wait_for_load_state("networkidle")` después de la navegación de página para asegurar que los recursos estén cargados.
- Agregado lógica de descarte del banner de consentimiento de cookies.
- Agregado esperas explícitas para la visibilidad de elementos para mejorar la fiabilidad.
- Agregado soporte de selección de versión Windows 10/11.

## Solución de Problemas

Si el script falla:

- Asegúrese de que Docker esté en ejecución y accesible.
- Verifique que el argumento de idioma coincida exactamente con lo que muestra Microsoft (mayúscul/minúscul).
- Verifique que el argumento de versión de Windows sea ya sea "10" o "11".
- El script puede fallar si Microsoft cambia el diseño de su sitio web; en ese caso, los selectores de Playwright pueden necesitar actualizarse.




ATENCION, AVISO (12 de octubre de 2026): microsoft cortara el acceso a partir
del 19 de junio del 2027 el acceso a windows update a todos los equipos que
tengan windows 10 sin ESU hacia abajo (el bloqueo anterior fue hasta windows
vista-server 2008 sin R2), esto logicamente afecta a las versiones de servidor
(server 2008 R2 hasta server 2019, a partir de server 2022, no afecta el cierre
de windows update), esto es debido a la caducidad de los certificados raiz
del servicio de actualizaciones que caduca a partir de esta fecha, si quieres
echar un vistazo al link oficial de la noticia de microsoft, aqui te lo paso (usa la traduccion del navegador, esta en ingles):

https://techcommunity.microsoft.com/blog/windows-itpro-blog/prepare-for-windows-update-certificate-rotation-in-2027/4562463

recuerda que los certificados raiz forman parte de la navegacion por internet, una de las caracteristicas del protocolo https
es que ahora todo lo que se transfiere al router esta cifrado (anteriormente no era asi), pero para que programas que se uti
lizan para analizar todo lo que se transfiere en una red domestica como wireshark no surta ningun efecto (no se vea ningun
dato sensible), los certificados raiz deben de funcionar y estar al dia, si no funciona, da error de certificado en el navegador
y los programas que conectan a internet dejaran de funcionar, esto lo tienes que tener en cuenta a la hora de utilizar un windows
antiguo instalado en el ordenador (por cierto, el cierre de windows update tambien afecta a las maquinas virtuales, o sea, a los PCs
arrancados dentro de un equipo fisico).

cuando llegue la fecha de caducidad del certificado raiz es posible que en los offices instalados en windows sin soporte den errores
de comprobacion de actualizaciones (hasta 10 y server 2019 que son cliente y servidor respectivamente se puede instalar el 2021-365
7 y 8, hasta office 2016), solucionandose esto desactivando las actualizaciones de office (cuando llegue la fecha de caducidad de
dichos certificados raiz).

en la ventana anterior (las actualizaciones automaticas se impusieron a partir de windows 2000) no dio ningun tipo de fallo a la
hora de arrancar el sistema operativo, unicamente a la hora de abrir la pagina de microsoft update o iniciar el windows update.
(pase la experiencia de la ventana anterior de cierre del update).

en el caso de que sea windows 10 con ESU, windows 11 24H2, servers LTSC de 2019 y 2016 y server 2022, microsoft ha puesto como
metodo oficial para solucionar el problema, la actualizacion, o sea, que tendras que actualizar el segundo martes de cada mes
hasta la fecha del 19 de junio de 2027 en el cual ya...piano, piano (entenderas lo que te digo).

en el caso de que te encuentres con este tipo de equipos, estos son los caminos que tienes:

-  comprar el ESU (windows 10) (en el caso de paises de la union europea, no tiene ningun coste) 
-  parchear el update para acceder al ESU, que el unico parche (y recomendable para windows 10) es el MAS (microsoft activation script)
-  instalar un parche no oficial para actualizar los certificados raiz, que es el legacy update
-  en el caso de versiones compatibles (no es obligatorio por el momento a partir de 11 24H2, windows 10 sin ESU es imprescindible
a medias) aceptar las actualizaciones a versiones mayores de windows via update o haciendo una actualizacion desde los medios de
instalacion de windows.
-  mantener la instalacion de windows y hacer un dual boot con linux (no aconsejable).
-  desinstalar windows e instalar linux junto con una maquina virtual de windows (ahi se permite todo, desde originales hasta modificados)

en el caso de que elijas la opcion sensata (la ultima), recuerda que debes de montar vmware o virtualbox en linux (instala linux en el ordenador
logicamente) y la maquina virtual con el windows a elegir (que ahi si puedes instalar windows antiguos) de manera oficial hasta junio de 2027, posteriormente
no va a funcionar y solo vas a poder instalar y actualizar este tipo de PCs por metodos no oficiales.

en el caso de que hayas perdido tu empleo o el curso al haberle dicho este inconveniente, mucha suerte en tu busqueda de empleo o en la busqueda de curso
(que espero que lo encuentres), con todas estas pistas que te digo ya veras como seguro al final encuentras el empleo o curso soñado.