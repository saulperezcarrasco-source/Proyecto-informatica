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

Dispositivos detectados para la revisión nativa: Infinix X6525 conectado por
USB, Android 13, pantalla 720×1612 / densidad 320; Pixel_10a emulado, Android 17
API 37, pantalla 1080×2424 / densidad 420. Los resultados de instalación y
ejecución se registran al completar la entrega; no se presenta la detección
del dispositivo como una prueba de funcionamiento.

No se modifican datos cartográficos, motor de rutas ni seguimiento GPS.
