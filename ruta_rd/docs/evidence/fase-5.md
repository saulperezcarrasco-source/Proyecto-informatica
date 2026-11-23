# Fase 5 — GPS y permisos

19 de noviembre de 2026. Implementación Android de una consulta puntual solicitada exclusivamente al pulsar Mi ubicación.

LocationService permite sustituir el proveedor por un servicio falso. GpsLocationService usa geolocator 14.1.2 y una frontera GpsPlatform inyectable. Se consultó el README de la versión instalada: permisos FINE y COARSE ya estaban declarados y se conserva la selección aproximada de Android. No se añade permiso de ubicación en segundo plano ni se inicia una suscripción continua.

La primera prueba offline mostró que el proveedor de Google solicitaba activar escaneo Wi-Fi. El adaptador Android ahora usa AndroidSettings con forceLocationManager para consultar el gestor de ubicación del sistema sin exigir ese servicio adicional. Se mantienen la consulta puntual, precisión alta y límite de 15 segundos. La precisión aproximada sigue dependiendo del permiso concedido y de la disponibilidad del proveedor del sistema.

Se distinguen servicio desactivado, denegación, bloqueo permanente, timeout, posición inválida, fuera de cobertura y error de proveedor. El tiempo máximo de obtención de posición es 15 segundos. Abrir permisos de la app solo aparece ante bloqueo permanente; Activar ubicación abre los ajustes de ubicación ante servicio desactivado. En los demás casos el usuario puede reintentar o elegir el origen en el mapa.

Una lectura inválida o fuera de la isla no sustituye origen, destino ni ruta. Elegir un origen manual, limpiar o cancelar GPS descarta la consulta pendiente. Destruir el controlador descarta tanto éxitos como errores tardíos. Los toques repetidos mientras existe una consulta no disparan más peticiones.

La precisión y la condición de ubicación aproximada se muestran junto al origen GPS y permanecen visibles aunque se calcule una ruta. El mapa dibuja un círculo de incertidumbre y ajusta el encuadre para lecturas de precisión superior a 100 m. La representación del círculo se limita a 100 km; el texto conserva la precisión recibida. Los puntos manuales mantienen el comportamiento inmediato sin refresco.

## Comprobaciones

- dart format: aplicado.
- flutter analyze: sin problemas.
- flutter test: 35 pruebas aprobadas. Incluyen permisos, límite de 15 segundos, precisión aproximada, timeout, posición inválida, recuperación, conservación de puntos/ruta, ausencia de solicitudes iniciales, bloqueo de llamadas simultáneas, cancelación, selección manual durante consulta y destrucción del controlador.
- Matriz Android nativa: comprobada en Pixel_10a, Android API 37, en el APK release normal. Todas las consultas se probaron con Wi-Fi y datos apagados.
- Teléfono físico con Wi-Fi y datos apagados: pendiente; no se dispone de uno conectado.

La fase no se declarará aceptada por completo mientras falte la evidencia Android física exigida por el plan.

## Matriz Android observada

| Caso | Preparación y resultado |
|---|---|
| Primera apertura | Con permisos revocados se abrió sin diálogo. Solo Mi ubicación inició la solicitud nativa. |
| Permiso concedido | Diálogo Android, permitir durante uso; posición simulada 18.47370, -69.88440. Se mostró ±5 m y el punto A. [Captura](fase5-gps.png). |
| Fuera de cobertura | geo fix a 51.5, -0.1; se mostró el aviso y se conservó A dentro de Ciudad Colonial con su precisión anterior. [Captura](fase5-fuera.png). |
| Servicio desactivado | cmd location set-location-enabled false; aviso y Activar ubicación. El botón abrió el ajuste de ubicación del sistema; se reactivó después. [Captura](fase5-desactivado.png). |
| Denegación | Se denegó en el diálogo real; la selección manual 19.13400, -72.39464 permaneció disponible, sin nuevos diálogos automáticos. [Captura](fase5-denegado.png). |
| Bloqueo permanente | Se configuró el estado Android con permisos revocados y banderas USER_SET/USER_FIXED. No se mostró otro diálogo; apareció Abrir permisos de la app, que abrió InstalledAppDetails. Se limpiaron las banderas al finalizar. [Captura](fase5-bloqueado.png). |
| Solo aproximada | Se eligió Approximate en el diálogo real. Android confirmó FINE=false, COARSE=true. Se obtuvo 18.46847, -69.88743 con ±2.000 m, etiqueta de ubicación aproximada y círculo encuadrado. [Captura](fase5-aproximada.png). |
| Sin posición / timeout | Se instaló temporalmente un proveedor de prueba fused sin emitir una posición. Tras el límite se mostró el aviso de tiempo agotado, conservando el origen aproximado anterior. El proveedor fue retirado y el permiso de simulación de shell se devolvió a su valor predeterminado. [Captura](fase5-timeout.png). |
| Recuperación y ruta | Restaurado el proveedor normal y el permiso preciso, Mi ubicación volvió a obtener ±5 m. Se colocó B en 18.47313, -69.88626; la ruta automática resultó en 166 m, con accesos separados de 21 m y 20 m. La precisión permaneció visible junto al origen. [Captura final](fase5-ruta-gps.png). |

Cancelación, selección manual durante una consulta y destrucción del controlador se probaron con futuros controlados en las pruebas automatizadas; no se presentan como ejecuciones físicas. Los valores GPS anteriores son simulaciones del emulador, no mediciones de un receptor físico.

Entrega final: APK release x64 de demostración (172,3 MB), instalado y abierto en el emulador. No se encontraron excepciones fatales de Flutter/Android en los registros del proceso durante la comprobación final. Se restauraron Wi-Fi, datos móviles y el servicio de ubicación, y se dejó abierta la aplicación normal con el origen GPS y la ruta automática. El manifiesto fusionado contiene FINE y COARSE sin ACCESS_BACKGROUND_LOCATION.
