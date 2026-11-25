# GPS satelital sin red — 1.5.1-demo+11

25/11/2026. Se termina la corrección solicitada tras el fallo de ubicación precisa
sin internet en navegación. La versión anterior esperaba una consulta puntual
con límite de 15 s antes de abrir el stream; si la adquisición inicial tardaba
más, no comenzaba el seguimiento. También se observó que geolocator_android
5.2.1 elegía el proveedor Android `fused` antes que `gps` en Android 12+ aun
usando LocationManager.

La navegación ahora solicita explícitamente GPS_PROVIDER mediante un EventChannel
Android propio, con actualizaciones de 1 s / 0 m para recibir mejoras de precisión
incluso estando quieto. No necesita tráfico de red de la app ni proveedor de
ubicación de Google. No se usa una posición almacenada como una lectura nueva.
El stream empieza tras comprobar permisos, sin esperar una consulta puntual ni
imponer un timeout al primer fix. Cancelar libera el proveedor y la pantalla
solo permanece encendida mientras el seguimiento está activo.

Al regresar a la app se reanuda una navegación interrumpida por el ciclo de vida;
la pausa manual se mantiene. Los errores de permiso preciso o ubicación apagada
incluyen acciones para abrir ajustes. Se conservan los filtros de antigüedad,
precisión y saltos: no se reduce artificialmente la exigencia de precisión para
mostrar avance. La consulta GPS puntual de planificación mantiene su contrato
de tiempo máximo de 15 s.

Validación local: análisis sin incidencias y 68 pruebas aprobadas, incluidas
espera prolongada, refinamiento de precisión en reposo, cancelación sin recibir
ningún fix, permisos, recuperación al volver y conservación de pausa manual.
La prueba Android usa GpsLocationService y el nuevo canal nativo, con puntos
inyectados solo en el emulador sobre una ruta piloto real. Pasó en Pixel_10a /
Android 17 API 37, modo avión activado, Wi-Fi y datos desactivados: la posición
movió la flecha y la distancia bajó 209,70 → 104,97 → 0 m, con ±5 m informados
por el GPS simulado. Se alcanzó el destino sin recalcular la ruta por cada fix.
Se esperaron 18 s antes de inyectar el recorrido y se verificó en dumpsys la
suscripción directa de la app al proveedor `gps`, a 1 s y HIGH_ACCURACY.
La prueba aprobada usa el receptor nativo del emulador; no acredita satélites
físicos. La aplicación normal se reinstala después del fixture de integración.

La aplicación normal release 1.5.1-demo+11 también pasó la revisión nativa en
modo avión, Wi-Fi y datos apagados: 209 → 104 → 0 m, flecha móvil, llegada,
reanudación después de ir a Inicio y vuelta a la app, y pausa manual conservada
al hacer lo mismo. Se aceptó el permiso preciso solicitado por Android.
Al salir de navegación quedó abierto el mapa principal con su ruta, y se
restauraron los ajustes de red originales del emulador.

APK universal de 208.531.590 bytes; código compilado
`c01dd0cf3e54d1517af813a7b830caf525a6a6e4`; SHA256
`4bc8b2b495bb286d52eb322308d6b7072de428c372b7ceae31cbf4d62bdf0bd1`.
Firma, ARM32/ARM64/x64 y alineación ZIP/ELF de 16 KB aprobadas.
Capturas del APK normal: [avance](gnss-offline-avance.png),
[llegada](gnss-offline-llegada.png) y [pantalla final](gnss-offline-final.png).

El usuario solo puede probar el teléfono dentro de casa y, el 25/11, pidió
continuar con emulador y APK. Por tanto, esta entrega no acredita recepción
GNSS física ni precisión real al aire libre. La disponibilidad y precisión
dependen de la recepción de satélites; referencia:
[LocationManager de Android](https://developer.android.com/reference/android/location/LocationManager).
