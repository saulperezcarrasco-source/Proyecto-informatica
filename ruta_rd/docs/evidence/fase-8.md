# Fase 8 — integración y entrega

20/11/2026. Alcance: MVP y favoritos, con validación en Pixel_10a / Android 17
API 37, sin exigir un teléfono físico según la instrucción del usuario.
Filtros, accesibilidad adicional y ampliaciones posteriores no se incorporan
a esta entrega. Se mantiene el código de rutas y la cartografía previamente
revisada, sin servicios remotos ni nuevas dependencias.

Se revisaron la carga de manifiesto regional, el almacenamiento de favoritos,
su controlador, recuperación de errores y conexión a HomeScreen. Se integró
una sola rama, feat/favorites, mediante merge local revisado `5e67d42`, sin
conflictos. Sus commits principales son `32d256e`, `a3307f4` y `41efed1`.
Se utilizó la alternativa de merge local revisado permitida por el plan; no
se publicó un PR ni se enviaron cambios al remoto.

La versión de entrega es `1.0.0-demo+2`. Usa build release android-x64 y firma
de desarrollo Android, identificada como demostración. No se incluye ninguna
clave ni contraseña. La configuración existente conserva el keystore fuera
del repositorio; las reglas Git excluyen key.properties, jks y keystore.

La integración deja favoritos en el proyecto original ruta_rd de main.
Se prepara una carpeta entregables/v1.0.0-demo con APK, fuentes del commit,
manifiesto de procedencia, verificación de firma/versión, hashes, licencias,
instrucciones de instalación, guion de cinco minutos y video de respaldo.

Regresión después de integrar: formato sin cambios, análisis sin incidencias,
43 pruebas locales aprobadas y seis integraciones Android aprobadas (favoritos,
MVP, ruta nacional, tema/archivo local, búsqueda/selección y rutas piloto).
Se ejecutaron también tres escenarios GPS Android nativos aprobados: permiso
rechazado, ubicación desactivada y lectura inyectada exitosa con precisión
reportada de ±5 m. Los tres conservaron operación manual. Se ejecutó con modo
avión activado, Wi-Fi y datos apagados. [Salida conservada](fase8-resultados.txt).

Entrega completada y aceptada dentro del alcance de emulador/demo. Código
compilado: `29773b09250930b2805e5ff9fb69ddf998995d7d`; versión `1.0.0-demo+2`.
La etiqueta `v1.0.0-demo` incorpora después únicamente esta evidencia de cierre.
El ZIP de fuentes conserva exactamente el commit compilado, con el plan,
dependencias fijadas e instrucciones para reconstruirlo.

Se instaló exactamente `entregables/v1.0.0-demo/ruta-rd-v1.0.0-demo-android-x64.apk`:
102.886.359 bytes; SHA256
`ce9fc0271fcffb0b51b0c7d4c4e3d0d693ae8ee210dc53670c67d96a18e8316b`.
El SHA256 del APK instalado coincidió después de reiniciar Android. Firma
Android Debug verificada, esquema v2 válido; versionName y versionCode
inspeccionados con aapt. Incluye motor Flutter x86_64, mapa PMTiles y grafo
peatonal locales. No es un APK para teléfonos ARM ni una publicación Play.

Con datos borrados, modo avión, Wi-Fi y datos apagados, el primer arranque
release tardó 2.948 ms según Android ActivityManager. La reapertura manual
medida tardó 1.682 ms. Son observaciones individuales del emulador, no un
benchmark de dispositivos. Se comprobó mapa local, búsqueda «cafe», guardado
de dos favoritos y ruta azul automática de 166 m. Rechazar el permiso GPS
nativo mostró el error y conservó la ruta manual. Tras forzar el cierre se
conservaron ambos favoritos y el modo oscuro. Elegir A/B desde favoritos
calculó la misma ruta; eliminar un favorito conservó el trazado y dejó uno.
[Acta del APK](fase8-acta.json).

Se reinició Android con la aplicación normal release instalada. Persistieron
un favorito y el tema oscuro, y se volvió a buscar y trazar la ruta azul sin
conexión. La apertura tras ese reinicio tardó 9.666 ms; el proceso de la app
permaneció activo. La captura confirma la ruta y los registros del proceso
no contenían errores flutter:E ni AndroidRuntime:E en esa consulta. Al
terminar se restauraron Wi-Fi, datos y modo avión desactivado, dejando el
APK normal abierto. [Captura tras reinicio](fase8-reinicio-ruta.png).

El video `respaldo.mp4`, de 112,748 segundos y 540 × 1212 píxeles, registra
la ejecución del mismo APK. Se decodificaron con Chrome local fotogramas de
28,187, 56,374 y 84,561 segundos y se inspeccionaron visualmente: búsqueda,
trazado azul y tema oscuro. La presentación incluye guion de cinco minutos,
HTML local y PDF de ocho páginas, renderizado con Android PdfRenderer.
[Verificación multimedia](fase8-video-verificado.txt).

La carpeta de entrega incluye APK, ZIP de fuentes, video, presentación,
instrucciones, manifiestos de datos, licencias, capturas, firma verificada,
acta y SHA256SUMS. Todos los hashes se recalcularon y coincidieron después
del empaquetado final. [Manifiesto de entrega](fase8-entrega.json).

Los scripts `tools/build_demo.ps1` y `tools/package_demo.ps1` registran la
procedencia y rechazan código sin guardar, un commit distinto al compilado,
cambios de APK, firmas inesperadas y claves de firma registradas en Git.
Los archivos grandes de entrega quedan locales e ignorados por Git.

La búsqueda por nombres permanece limitada a 190 lugares del piloto Ciudad
Colonial. Las rutas y la selección manual cubren el grafo disponible de RD,
con errores explícitos para puntos sin conexión o sin camino próximo. No
incluye navegación para vehículos, tráfico ni certificación en terreno.
El GPS de prueba del emulador se identifica como posición inyectada. No se
afirma rendimiento de hardware físico, seguridad o accesibilidad en terreno.
