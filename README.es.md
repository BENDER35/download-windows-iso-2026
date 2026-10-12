# Descarga de imagen ISO de Windows

Guion bash para descargar la imagen ISO de Windows desde el sitio web de Microsoft usando Docker y Playwright.

## Requisitos

1. Tener `docker`
2. Tener `bash`
3. Tener `wget`

## Instalación

### En Windows

1. Descargue Docker Desktop desde: https://www.docker.com/products/docker-desktop
2. Ejecute el instalador y siga el asistente de configuración
3. Una vez instalado, abra Docker Desktop menú de inicio
4. Crear una cuenta Docker o inicie sesión si ya tiene una
5. Docker se iniciará automáticamente y verá el ícono de la ballena en la bandeja del sistema
6. Verifique la instalación ejecutando `docker --version` en PowerShell o Símbolo del sistema

### En Linux (Ubuntu/Debian)

```bash
# Actualizar el índice de paquetes
sudo apt-get update

# Instalar prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Agregar la clave GPG oficial de Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurar el repositorio
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Motor de Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verificar la instalación
sudo docker run --rm hello-world
```

### En Linux (Otras distribuciones)

Consulte la documentación oficial de Docker para su distribución específica:
https://docs.docker.com/engine/install/

## Uso

### Paso 1

```
# Predeterminado a `Windows 11, Inglés Internacional`
./download.sh [-l IDIOMA] [-w VERSION_WINDOWS]

# Descargar Windows 10, Inglés Internacional
./download.sh -l "Inglés Internacional" -w 10

# Descargar Windows 11, Español
./download.sh -l "Español" -w 11
```

### Paso 2

Verifique `./tmp/` para la ISO descargada.

### Paso 3

El script realizará las siguientes acciones:

1. Construirá una imagen Docker con Playwright instalado
2. Ejecutará un navegador para navegar a la página de descarga de Windows {10/11} de Microsoft
3. Mostrará advertencias de fin de soporte
4. Seleccionará la edición del producto y el idioma
5. Salida la página de URL de descarga directa
6.Nota: El sitio web de Microsoft puede requerir completar la descarga manualmente
   debido a medidas anti-bot. La URL de salida se puede usar con wget o un explorador.

### Advertencias Importantes

Al descargar Windows 10:

- **Soporte principal finalizado**: 14 de octubre de 2025
- **ESU (Actualizaciones de Soporte Extendido) finaliza**: 12 de octubre de 2027
  (Programa de pago de 3 años para recibir actualizaciones críticas e importantes de seguridad)
- **Microsoft puede retirar las descargas de ISOS en cualquier momento** - el vínculo de descarga puede volverse sin aviso previo
- Considere usar Windows 11 para recibir actualizaciones de seguridad continuadas y soporte

### Paso 4

El script salida una URL de página de descarga. Puede usar esta URL con wget o un explorador:

```bash
# Usando wget (puede requerir opciones adicionales para el sitio de Microsoft):
wget --content-disposition "URL_OUTPUT"

# O simplemente abra la URL en un explorador y haga clic en el botón de descarga:
# La URL se mostrará después de ejecutar el script
```

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
