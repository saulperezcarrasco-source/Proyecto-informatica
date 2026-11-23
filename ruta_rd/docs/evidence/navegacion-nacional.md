# Navegación peatonal, catálogo nacional y rendimiento — 1.1.0-demo+4

20/11/2026. Ampliación solicitada por el usuario tras detectar tirones en el
teléfono y comprobar que la consulta puntual de ubicación no seguía movimiento.

Se añade navegación en primer plano con flecha GPS, orientación al avanzar,
proyección sobre la ruta, distancia/tiempo restantes, llegada y giros derivados
de geometría. Pausa/salida/fondo cancelan el seguimiento. Una señal imprecisa,
vieja, fuera de RD o fuera de ruta no inventa avance. El recálculo desde posición
actual es explícito. La ruta y A/B originales no se recalculan por cada fix.
La vista amplia tiene tarjetas redondeadas y controles de seguimiento de cámara.
No se implementan rutas para vehículos ni seguimiento en segundo plano.

LocationService conserva consulta puntual y añade stream; Android usa
LocationManager con intervalo solicitado de 1 s y filtro de 2 m. Geolocator
14.1.2 existente, sin dependencias nuevas de ejecución. La precisión y cadencia
dependen del dispositivo. La flecha no es una brújula cuando se está quieto.

El catálogo incluye 95.118 registros con nombre de OSM, recortados a RD:
50.184 tramos de calles, 5.554 lugares/barrios/áreas, 15.521 de categoría negocio,
2.223 de turismo y otras categorías. No son negocios únicos ni todos los
lugares existentes. Fuente Geofabrik 18/11/2026, ODbL 1.0; no hay datos Google.
Se validaron IDs únicos, 0 coordenadas fuera de RD y SHA256 contra manifiesto.
La búsqueda se normaliza/indexa en isolate persistente y usa debounce de 220 ms.
Los IDs y favoritos piloto se conservan; los nacionales tienen namespace propio.

La prueba Android detectó que Flutter renombraba places.json.gz al empaquetar
assets precomprimidos. Se cambió a places.rds (gzip interno), y el verificador
ahora exige ese asset y valida su SHA256. La prueba local sola no detectaba
esa diferencia de empaquetado. Se conservaron las pruebas Android como criterio.

Optimizaciones: etiquetas rasterizadas por tesela, caché raster adaptativa,
sin miles de widgets de lugares y con base cartográfica estable. El filtro
territorial prueba primero un interior conservador de 82 vértices, y conserva
el límite exacto como respaldo. Se omite procesar la máscara de 6.871 vértices
solo si toda la vista es interior; se comprueban esquinas y cajas de segmentos
para no revelar recortes en países cóncavos ni en la frontera. El generador
demuestra inclusión y un margen mínimo de 0,0121167 grados. No cambia selección
ni grafo. Una frontera fuera de pantalla no requiere pintarse por cada frame.

Validación local: formato, análisis sin incidencias y **50 pruebas aprobadas**.
Incluyen movimiento, distancia decreciente/llegada, errores, pausa/disposición,
índice nacional real y casos de máscara con bordes y concavidades. Android:
favoritos, MVP, ruta nacional Dajabón–Santiago, selección, rutas piloto, tema y
navegación aprobados en sus ejecuciones; el caso nuevo verifica 95.308 lugares
combinados, flecha accesible, pausa, llegada y conservación del RouteResult.

Se conectó y ejecutó un teléfono real T-Mobile REVVL 7 (TMRV075G), ARM64,
Android 16 API 36, 1080×2408/densidad 480, texto 1,0, páginas de 4 KB.
La prueba profile AOT ejecuta el código optimizado, catálogo real y mapa local,
con movimiento deliberadamente simulado en LocationService. No acredita GPS
físico ni una caminata. No se ordenó borrar datos ni desinstalar en el teléfono.

Medición de 120 movimientos continuos de cámara, zoom 15,5–17,25 en Santo
Domingo, mismo harness y teléfono. Con filtro interior pero máscara siempre
procesada: UI media 38,002 ms, P90 80,104 ms, 121/234 muestras UI >16,67 ms.
Después de omitir máscara fuera de vista: UI media **1,9195 ms**, P90 **5,137 ms**,
**0/301** muestras UI >16,67 ms; raster media 2,727 ms y P90 3,16 ms.
Se usa benchmarkLive con temporizadores reales y FrameTiming; se descartaron
mediciones anteriores con pump(Duration) que incluían pausas del test.
Es una comparación de ese escenario, no una garantía de FPS en todo RD,
todos los teléfonos, estados térmicos o niveles de zoom.
flutter_driver se añade solo como dependencia de desarrollo del SDK para
repetir esa medición; el APK normal no ejecuta el driver ni posiciones simuladas.

Entrega normal final: código `e83ea01abd2d4fdf8f030b0f64a63d30b30a7188`,
`ruta-rd-v1.1.0-demo-android-universal.apk`, 139.139.316 bytes. SHA256:
`515b2efa0789d2df00acef6db741f2f68d04659ed3404e2381606232dfa747a9`.
Los ajustes posteriores a la medición AOT acercan inicialmente a zoom 17 para
que la flecha no tape rutas cortas, eliminan controles superpuestos y evitan
notificaciones repetidas al arrastrar. La optimización de máscara medida no
cambia. Tras esos ajustes se repitieron análisis y las 50 pruebas locales.

El mismo APK normal se instaló y abrió en Pixel_10a y en REVVL 7. Ambos
base.apk instalados coincidieron con el SHA256 de entrega, mantuvieron proceso
activo y no devolvieron errores flutter:E/AndroidRuntime:E en la consulta por
PID final. El APK incluye motores completos ARM32, ARM64 y x64; firma de demo,
ZIP de 16 KB y segmentos ELF64 de al menos 16 KB verificados. También se
validó el SHA256 del catálogo dentro del APK. [Registro](navegacion-entrega.json),
[instalaciones](navegacion-instalaciones.json).

En el emulador, se borraron solo los datos de la app de prueba y se ejecutó
el APK normal sin conexión. Con ubicación y permisos Android reales, emu geo
fix suministró posiciones GNSS conocidas. LocationManager/getPositionStream
actualizó **190 → 107 → 0 m**, giró y movió la flecha y mostró llegada. Se
inspeccionaron las capturas del inicio, avance y llegada, con línea azul visible.
No se sustituyó LocationService por un fake en este caso. [Acta](navegacion-gnss-acta.json),
[inicio](navegacion-gnss-inicio.png), [avance](navegacion-gnss-avance.png),
[llegada](navegacion-gnss-llegada.png).

En el teléfono, el APK final abrió COLD en 1.115 ms. Mediante teclado y controles
nativos se buscó Puerto Plata como B y Santiago como A; calculó una ruta azul
de 59.065 m, con estimación peatonal de 788 min. Se inspeccionó la captura.
No se borraron datos ni se consultó ubicación física en esa prueba. No se
desactivó la conectividad del teléfono; el ensayo offline estricto se hizo en
el emulador. [Acta de teléfono](navegacion-telefono-acta.json).

Al finalizar se dejaron las aplicaciones normales instaladas y abiertas;
se restauró la conectividad del emulador y el ajuste temporal de pantalla del
teléfono. La prueba de GPS caminando en terreno queda pendiente; no se presenta
la simulación GNSS ni el recorrido del harness como una caminata física.
[Salidas funcionales](navegacion-resultados.txt),
[medición del teléfono](navegacion-profile-telefono.txt),
[comprobación de datos](navegacion-datos.txt).
