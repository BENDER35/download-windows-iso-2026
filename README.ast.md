# Descargar ISO de Windows

Script de bash pa descargar ISOs de Windows dende la páxina web de Microsoft usando Docker y Playwright.

## Requisitos

1. Tener `docker`
2. Tener `bash`
3. Tener `wget`

## Instalación

### En Windows

1. Descarga Docker Desktop dende: https://www.docker.com/products/docker-desktop
2. Executa l'instalador y sigue l'asistente de configuración
3. Una vegada instaláu, abre Docker Desktop dende'l menú d'Entamu
4. Crea una cuenta de Docker o inicia sesión si yá tienes una
5. Docker va arrancar automáticamente y vas ver l'iconu de la ballena na bandexa del sistema
6. Comprueba la instalación executando `docker --version` en PowerShell o en Command Prompt

### En Linux (Ubuntu/Debian)

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation
sudo docker run --rm hello-world
```

### En Linux (otres distribuciones)

Mira la documentación oficial de Docker pa la to distribución concreta:
https://docs.docker.com/engine/install/

## Úsu

### Pasu 1

```
# Default to `Windows 11, English International`
./download.sh [-l LANGUAGE] [-w WINDOWS_VERSION]

# Download Windows 10, English International
./download.sh -l "English International" -w 10

# Download Windows 11, Spanish
./download.sh -l "Español" -w 11
```

### Pasu 2

Mira en `./tmp/` la ISO descargada.

### Pasu 3

El script va:

1. Construyir una imaxe de Docker con Playwright instaláu
2. Executar un navegador pa navegar a la páxina de descarga de Microsoft Windows {10/11}
3. Amosar los avisos de fin de soporte
4. Escoyer la edición del productu y la llingua
5. Amosar l'URL de la páxina de descarga direuta
6. Nota: la páxina web de Microsoft pue riquir completar la descarga a mano por midíes anti-bot. L'URL amosao embaxo pue usase con wget o con un navegador.

### Avisos importantes

Al descargar Windows 10:

- **El soporte principal finó**: 14 d'ochobre de 2025
- **L'ESU (Extended Support Updates) fina**: 12 d'ochobre de 2027
  (programa de pagu de 3 años pa recibir actualizaciones de seguridá crítiques ya importantes)
- **Microsoft pue retirar les descargues d'ISOs en cualquier momentu** - l'enllaz de descarga pue dexar de tar disponible ensin avisu
- Valora usar Windows 11 pa siguir recibiendo actualizaciones y soporte de seguridá

### Pasu 4

El script da como salida un enllaz a la páxina de descarga. Pues usalu con wget o con un navegador:

```bash
# Using wget (may require additional options for Microsoft's site):
wget --content-disposition "URL_OUTPUT"

# Or simply open the URL in a browser and click the download button:
# The URL will be displayed after the script runs
```

## Versiones (pa caltenedores)

`release.sh` automatiza les xeres de caltenimientu d'una versión: quita los contenedores de Docker que dexó `download.sh`, sincroniza los cambeos de trabayu y publica una versión de GitHub con un ficheru zip como recursu (más un `.sha256`).

```bash
./release.sh                   # remove the latest ISO container, sync and publish
./release.sh --all-containers  # purge every container of the ISO image
./release.sh --dry-run         # show what would happen without changing anything
./release.sh -v v2.0.0         # publish an explicit version
./release.sh -m "fix: ..."     # custom commit message
```

L'autenticación usa un token col ámbitu `repo`, lleíu d'un ficheru `./.secrets` ensin siguir pol git o de la variable d'ente `GITHUB_TOKEN`:

```bash
echo 'GITHUB_TOKEN=ghp_xxx' > .secrets
chmod 600 .secrets
```

Opciones: `-b/--branch`, `-s/--source`, `-t/--token-file`, `-v/--version`,
`-m/--message`, `-a/--all-containers`, `--no-container`, `-n/--dry-run`, `-h`.
Executa `./release.sh --help` pa ver la llista completa y les sustituciones per mediu de variables d'ente.

ATENCIÓN, AVISU (12 d'ochobre de 2026): Microsoft va cortar a partir del 19 de xunu de 2027 l'accesu a Windows Update pa toos los equipos que tengan Windows 10 ensin ESU o inferior (el bloqueu anterior foi hasta Windows Vista/Server 2008 ensin R2); esto afecta lógicamente a les versiones de servidor (de Server 2008 R2 a Server 2019; a partir de Server 2022, el zarru de Windows Update nun los afecta). Ye por mor de la caducidá de los certificaos raíz del serviciu d'actualizaciones, que caduquen a partir d'esta data. Si quies echar una güeyada al enllaz oficial de la noticia de Microsoft, equí lo tienes (usa la traducción del navegador, ta n'inglés):

https://techcommunity.microsoft.com/blog/windows-itpro-blog/prepare-for-windows-update-certificate-rotation-in-2027/4562463

Recuerda que los certificaos raíz formen parte de la navegación per Internet; una de les carauterístiques del protocolu https ye que agora too lo que se tresfier al router ta cifráu (enantes nun yera asina). Sicasí, pa que programes como Wireshark, que s'usen pa analizar too lo que se tresfier nuna rede doméstica, nun tengan efeutu (nun se vea ningún datu sensible), los certificaos raíz tienen de funcionar y tar al día. Si nun funcionen, da un error de certificáu nel navegador y los programes que conecten a Internet dexarán de funcionar. Tienes que tener esto en cuenta cuando uses un Windows antiguu instaláu nel ordenador (per ciertu, el zarru de Windows Update tamién afecta a les máquines virtuales, esto ye, a los PCs arrancaos dentro d'un equipu físicu).

Cuando llegue la data de caducidá del certificáu raíz, ye posible que los Office instalaos en Windows ensin soporte den errores al comprobar actualizaciones (hasta 10 y Server 2019, que son veceru y servidor respeutivamente, puedes instalar el 2021-365, 7 y 8, hasta Office 2016); esto se resuelve desactivando les actualizaciones d'Office (cuando llegue la data de caducidá d'esos certificaos raíz).

Na ventana anterior (les actualizaciones automátiques impunxéronse a partir de Windows 2000) nun dio nengún tipu de fallu al arrancar el sistema operativu, namás al abrir la páxina de Microsoft Update o al iniciar Windows Update. (Yo pasé pela ventana anterior de zarru del update).

Nel casu de que seya Windows 10 con ESU, Windows 11 24H2, servidores LTSC de 2019 y 2016 y Server 2022, Microsoft punxo como métodu oficial pa resolver el problema la actualización: vas tener que actualizar el segundu martes de cada mes hasta la data del 19 de xunu de 2027, en qu'a yá... piano, piano (vas entender lo que te digo).

Nel casu de que te topes con esti tipu d'equipos, estes son les opciones que tienes:

-  mercar l'ESU (Windows 10) (nel casu de países de la Xunión Europea, nun tien ningún costu)
-  parchear el update pa acceder al ESU, l'únicu parche (y recomendable pa Windows 10) ye'l MAS (Microsoft Activation Script)
-  instalar un parche non oficial pa actualizar los certificaos raíz, que ye Legacy Update
-  nel casu de versiones compatibles (por agora nun ye obligatoriu dende 11 24H2; pa Windows 10 ensin ESU ye imprescindible a medies) aceptar les actualizaciones a versiones mayores de Windows per mediu d'actualización o faciendo una actualización dende los medios d'instalación de Windows.
-  caltener la instalación de Windows y facer un dual boot con Linux (nun ye aconseyable).
-  desinstalar Windows ya instalar Linux xunto con una máquina virtual de Windows (ellí se permite too, dende orixinales hasta modificaos)

Nel casu de que escojas la opción sensata (la postrera), recuerda que tienes de montar VMware o VirtualBox en Linux (instala Linux nel ordenador, lóxicamente) y la máquina virtual col Windows que escojas (ellí sí que puedes instalar Windows antiguos) de manera oficial hasta xunu de 2027; dempués nun va funcionar y namás vas poder instalar y actualizar esti tipu de PCs per métodos non oficiales.

Nel casu de que hayas perdíu l'empleu o'l cursu por haber dichu esta molestia, muncha suerte na busca d'empleu o na busca de cursu (esperu que lo atopes); con toles pistes que te digo yá verás cómo, seguro, al final atopes l'empleu o'l cursu soñáu.
