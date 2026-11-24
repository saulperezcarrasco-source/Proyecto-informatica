# Pantalla fija — 1.5.0-demo+10

24/11/2026. Solicitud: quitar el desplazamiento de la pantalla principal,
probar también el dispositivo conectado por USB y entregar un APK.

El mapa ya no tiene una altura fija sumada al resto de la página. Una columna
con espacio flexible lo mantiene dentro del área visible. Búsqueda, transporte
y acciones se mantienen arriba. Solo la lista de resultados, favoritos y
diálogos de detalle pueden desplazarse dentro de sus propios límites.

La distribución reduce controles durante la escritura y admite texto grande.
En horizontal con poca altura los campos se colocan uno junto al otro; ubicación,
favoritos, tema y transporte siguen accesibles en «Más opciones». Los estados de
error del mapa ofrecen una acción compacta cuando hay poco espacio.

Validación local: análisis sin incidencias y 64 pruebas aprobadas. Las pruebas
incluyen 320×480 y 640×320 con texto al 200 %, teclado de 300 px con texto al
150 %, lista desplazable sin mover los campos, mapa dentro del área visible,
ruta A/B y punto inmediato sin recrear el mapa.

Dispositivos usados en la revisión nativa: Infinix X6525 conectado por
USB, Android 13, pantalla 720×1612 / densidad 320; Pixel_10a emulado, Android 17
API 37, pantalla 1080×2424 / densidad 420. El mismo APK normal release se instaló
y abrió en ambos con actualización `-r`, sin desinstalar ni borrar sus datos.

En el emulador pasó la prueba nativa de posiciones fijas tras un gesto vertical,
teclado, búsqueda A/B, cuatro transportes, edición de un extremo sin borrar el
otro, detalles, favoritos y tema. El mapa permanece dentro de la pantalla.

En el teléfono se probaron entradas y gestos ADB, revisando las capturas de la
aplicación real. Búsqueda con teclado, selección A/B y ruta azul automática:
166 m / 3 min a pie, 166 m / 1 min en bici, 1,2 km / 2 min en coche y 1,2 km /
3 min en moto, entre Café Conde de Peñalba y Café La Moricette. La cabecera
conservó exactamente sus píxeles muestreados tras deslizar verticalmente en el
margen de la página. El árbol UIAutomator del Infinix devolvía raíz nula; por eso
esta validación combinó entradas por coordenadas y revisión visual, sin afirmar
que se ejecutó allí el mismo script de accesibilidad del emulador.

APK: 208.531.590 bytes; código compilado
`91af584e3cafda6cb95d1297ad45d06e3b2fc6b1`; SHA256
`0b03b7611a93ad4e2f0082948f44d485f4d86efcdaa394559c3aa9645a333d25`.
Android informa `versionName=1.5.0-demo`, `versionCode=10` en ambos. Los hashes
SHA256 de los APK instalados coinciden con el entregado. Firma, tres ABI y
alineación ZIP/ELF de 16 KB verificadas. Ambas aplicaciones quedaron abiertas.

Capturas: [teléfono y ruta](fija-usb-ruta.png), [teclado físico](fija-usb-teclado.png),
[bici](fija-usb-bici.png), [coche](fija-usb-coche.png), [moto](fija-usb-moto.png),
[emulador](fija-emulador-final.png), [teclado emulado](fija-emulador-teclado.png).

No se modifican datos cartográficos, motor de rutas ni seguimiento GPS.
No se midió navegación GPS en movimiento ni rendimiento con un benchmark en
este cambio; las pruebas físicas descritas corresponden al Infinix indicado.
