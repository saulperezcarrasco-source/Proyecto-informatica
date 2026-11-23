# Fase 6 — validación del MVP

## Cierre posterior de aceptación — 20/11/2026

La comparación cartográfica pendiente quedó completada contra OSM actual:
[cinco lugares, cinco conexiones y trazabilidad del piloto](revision-cartografica.md),
sin discrepancias. Con las 37 pruebas locales, las ocho comprobaciones Android
y las instalaciones limpias aprobadas abajo, se cierra el MVP en el alcance de
emulador definido por el usuario. Su instrucción de avanzar una vez completada
esta fase habilita la fase 7. Se conserva la limitación de hardware físico y
de condiciones en terreno; la etiqueta `mvp-v0.1.0` identifica esta base estable.
Los estados pendientes que aparecen en el registro histórico describen los
momentos anteriores a este cierre.

## Alcance vigente desde el 20/11/2026

Por solicitud expresa del usuario, se repite la fase completa en el emulador
Pixel_10a, sin exigir un teléfono Android. Se conservan los datos y funciones
implementados y se repiten las pruebas desde un arranque en frío, incluyendo
instalaciones limpias debug y release sin conexión. Se añaden pruebas del
adaptador GPS Android nativo con permisos y ubicación controlados desde ADB.
Las coordenadas inyectadas se identifican como simuladas. Ninguna prueba del
emulador se presenta como evidencia de recepción GPS o rendimiento físicos.
El intento anterior de QA en teléfono no produjo un registro completo y no
cuenta como prueba aprobada.

### Resultado de la repetición: aprobado en el alcance de emulador

Código y herramientas del APK final:
`36310c949af2027765a82bfcd4c87dd28324294e`. La documentación posterior no
modifica la aplicación. [Resultados conservados](fase6-reinicio-resultados.txt).

- Formato comprobado, `flutter analyze` sin incidencias y **37 pruebas locales
  aprobadas**. Se repitieron los diez pares del grafo de la tabla histórica.
- **Cinco integraciones Android aprobadas**, con Wi-Fi y datos apagados:
  flujo completo MVP; dos toques y ruta nacional; tema y archivo local;
  búsqueda/selección; rutas piloto, resumen, mismo nodo, cambio y limpieza.
  Los recorridos verifican conexiones dirigidas reales, rechazo de Haití y
  recuperación de componentes desconectados, sin líneas inventadas.
- Dajabón–Santiago: 130.283,870 m y 2.342 vértices; primer cálculo debug,
  incluyendo carga del grafo, **1.584,989 ms**. Los marcadores aparecen en el
  siguiente fotograma sin recrear la cartografía ni mover la cámara.
- **Tres integraciones GPS nativas aprobadas**: permiso rechazado, servicio
  desactivado y lectura exitosa. Las dos primeras conservaron el origen anterior.
  En los tres casos se pudo calcular después una ruta manual de 597,657 m.
  La lectura exitosa usó coordenadas **inyectadas en el emulador**, precisión
  reportada de ±5 m y permiso preciso; no es recepción GPS física.
- Se repitió la auditoría de red: archivos y estilos locales, sin glyphs/sprites
  remotos; URL ficticia interceptada por un cliente de archivos. El manifiesto
  release combinado no solicita `INTERNET`. No se añadieron dependencias.

Se corrigieron dos problemas del procedimiento de pruebas y entrega:

1. Flutter desinstalaba el paquete al terminar cada integración. La matriz GPS
   ahora prepara primero un APK y usa `--no-uninstall` entre escenarios, antes
   de configurar permisos. El intento inicial incompleto no cuenta como aprobado.
2. Una actualización seguida de `pm clear` dejó una actividad anterior y Android
   eliminó el proceso con motivo `remove task`; apareció solo el fondo de inicio.
   QA lo detectó por la ausencia de PID y no generó un registro aprobado.
   `verify_phase6.ps1` y `run_android.ps1` ahora detienen la app y arrancan con
   `-S -f 0x10008000` (`NEW_TASK | CLEAR_TASK`). Se repitieron las instalaciones
   limpias después de corregirlo. Los arranques guardan su salida incluso si
   fallan, y el despliegue comprueba que exista el proceso.

El procedimiento también rechaza dispositivos ausentes antes de compilar,
comprueba ausencia efectiva de red y conserva cada ejecución en una carpeta
independiente por commit, dispositivo, modo y fecha UTC.

### Instalaciones limpias finales sin conexión

En ambos modos: instalación Success, hash instalado igual al APK, `pm clear`
Success, Wi-Fi/datos = 0 y **Active default network: none** antes de abrir.
Se revisaron visualmente las cuatro capturas. Primera apertura y reapertura
mostraron el mapa; todos los arranques registraron `Status: ok` y `COLD`.
No se encontraron `E/flutter`, `FATAL EXCEPTION` ni `Unhandled Exception` en
los registros de la app de estas ejecuciones finales.

| Modo x64 | Bytes del APK | Primera actividad | Reapertura de actividad | Registro |
|---|---:|---:|---:|---|
| debug | 249.294.941 | 9.623 ms | 8.780 ms | [JSON](fase6-final-debug.json) |
| release | 102.755.039 | 1.360 ms | 1.457 ms | [JSON](fase6-final-release.json) |

Estas cifras miden la actividad con `am start`, no el instante exacto de mapa
listo. Las capturas se solicitaron a los 22.004 ms y 13.785 ms desde las órdenes
de apertura, respectivamente. No son medidas de un teléfono físico.

Capturas debug: [primera apertura](fase6-final-debug-inicio.png) y
[reapertura](fase6-final-debug-reapertura.png). Capturas release:
[primera apertura](fase6-final-release-inicio.png) y
[reapertura](fase6-final-release-reapertura.png).

SHA256 debug:
`85f227b7f1ae631d5f8606a263c5db057c377cc43ec6dda9941e56251429d0dd`.
SHA256 release:
`fc669acf7468957ac597c49aeef3a669cec496c3c81fafc9578d9670c7ff9226`.
Ambos APK están identificados como PRUEBAS en `build/qa/36310c9/`, dentro de
sus subcarpetas de dispositivo, modo y ejecución.

### Entrega y reinicio final

Después de todas las pruebas se ejecutó `tools/run_android.ps1`, sin pruebas
Flutter en paralelo. Se reinstaló la aplicación normal release x64, sin ejecutor
de integración ni banner debug. Se reinició Android completo mediante ADB:
el paquete seguía instalado y el [mapa abrió sin red](fase6-final-reinicio.png),
con actividad `COLD`, `Status: ok` y `TotalTime: 6126` ms tras ese reinicio.
El hash instalado continuó coincidiendo con el release indicado arriba.

En esa aplicación normal se verificó el [modo oscuro al forzar detención y
reabrir](fase6-final-tema.png), y dos toques directos cerca de Santiago y Santo
Domingo generaron otra vez la [línea azul automática](fase6-final-ruta.png).
Se dejó esa vista abierta y se restauraron Wi-Fi/datos a 1. Una muestra de
[memoria después de la ruta](fase6-final-memoria.txt) registró PSS 165.255 KB
y RSS 290.784 KB; es una muestra del emulador, no un máximo ni medida física.

La repetición solicitada en emulador queda verificada. Se mantienen los límites
de datos descritos abajo: búsqueda por nombre piloto, rutas peatonales OSM y
accesos no verificados. La cartografía en terreno y el hardware físico siguen
sin evaluar, sin exigir un teléfono para esta entrega. No se crea etiqueta MVP
ni se inicia fase 7 automáticamente: requieren aceptación posterior.

## Registro histórico del 19/11/2026

19/11/2026. **En curso; MVP todavía no aceptado.** Las comprobaciones actuales
corresponden a Pixel_10a, Android API 37, `emulator-5554`. No hay un teléfono
físico conectado. No se crea `mvp-v0.1.0` ni se habilita fase 7.

## Pruebas automáticas

`flutter analyze`: sin incidencias. `flutter test`: **37 pruebas aprobadas**.
[Salida conservada de las pruebas](fase6-resultados.txt).
La integración `integration_test/mvp_acceptance_test.dart` pasó en Android con
Wi-Fi y datos apagados:

- Carga real de datos y apertura del archivo cartográfico local.
- Ninguna consulta GPS al abrir. Rechazo de permiso mediante un adaptador de
  prueba explícito, conservando búsqueda y selección manual operativas.
- Buscar `cafe`, elegir origen, buscar `café`, elegir otro destino y obtener
  automáticamente una línea azul: 166,188 m y 47,081 ms de cálculo debug.
- Rechazar un origen en Haití sin perder el origen válido; cancelar la selección.
- Limpiar elimina puntos, consulta y línea azul.
- Elegir un componente OSM realmente desconectado muestra el error recuperable
  «No hay conexión peatonal entre estos puntos.» sin dibujar una línea azul.
  Cambiar el destino a Puerto Plata produce una ruta válida en la misma sesión.

El rechazo inyectado prueba el flujo de interfaz, no un GPS físico. La matriz
de permisos nativos del emulador permanece documentada en [fase 5](fase-5.md).
Las comprobaciones de dos toques directos, actualización inmediata de marcadores,
recálculo y conservación del mapa están en [solo RD](solo-rd.md); el código de
producción no cambió en esta fase.

## Diez pares del grafo nacional

Coordenadas de referencia: Santiago `(19.4517,-70.697)`, Puerto Plata
`(19.793,-70.688)`, Santo Domingo `(18.4861,-69.9312)`, Punta Cana
`(18.582,-68.405)`, Barahona `(18.2085,-71.1008)`, Dajabón
`(19.54878,-71.70829)`.

| Caso | Origen → destino | Resultado esperado y obtenido |
|---|---|---|
| 1 | Santiago → Puerto Plata | Ruta de 56.808 m; 1.508 vértices |
| 2 | Santo Domingo → Punta Cana | Ruta de 186.712 m; 2.489 vértices |
| 3 | Barahona → Santo Domingo | Ruta de 192.493 m; 3.034 vértices |
| 4 | Dajabón → Santiago | Ruta de 130.284 m; 2.342 vértices |
| 5 | Puerto Plata → Santiago | Ruta de 56.808 m; 1.508 vértices |
| 6 | Punta Cana → Santo Domingo | Ruta de 186.712 m; 2.489 vértices |
| 7 | Santo Domingo → Barahona | Ruta de 192.493 m; 3.034 vértices |
| 8 | Santiago → Dajabón | Ruta de 130.284 m; 2.342 vértices |
| 9 | Haití `(19.55,-71.73)` → Santiago | `outsideCoverage` |
| 10 | Santiago → `(19.4009853,-70.6321272)` | `disconnected`; solicitud posterior válida |

Para cada uno de los ocho recorridos se comprueban todos los vértices dentro
de RD, la existencia de cada tramo como arista **dirigida** del grafo real y la
suma de sus pesos. Los accesos a la red quedan separados de la distancia sobre
el grafo. Los tiempos de estas pruebas en el ordenador no son rendimiento de
un teléfono. El caso 10 usa componentes del archivo real, no un enlace ficticio.

## Auditoría de funcionamiento local

No se añadieron dependencias. Mapa PMTiles, estilos, límite nacional, lugares y
grafo se incluyen en assets. Los estilos solo apuntan a `pmtiles://assets/...`;
no hay glyphs/sprites remotos ni fuentes web. La única URL HTTP de `lib` es
`local-archive.invalid`, interceptada por `LocalArchiveClient`: solo admite GET
con rangos sobre un `File`, rechaza otros destinos y no abre sockets.
El grafo se procesa en un isolate local. La procedencia OSM de los manifiestos
es metadato, no una descarga durante la apertura.

El manifiesto release combinado no solicita `INTERNET`; debug/profile lo
solicitan para las herramientas de Flutter. La presencia de esa dependencia
de desarrollo no se usa como evidencia offline: se comprueba con la red apagada.
Los datos de pruebas y los proveedores GPS inyectados no se empaquetan como
cartografía o lecturas reales de la aplicación normal.

## APK y primera apertura sin red

Revisión del APK: `a957fec4b60efd28ea51726baa3016f4039eaaeb`.
APK normal de QA generado con `flutter build apk --debug --target-platform android-x64`, identificado en el
nombre como **PRUEBAS**, sin ejecutor de integración. La revisión de evidencias
posterior solo añade documentación y capturas.

El procedimiento reproducible está en [docs/qa.md](../qa.md) y
`tools/verify_phase6.ps1`. Registra hash del archivo y del APK instalado, borra
solo los datos privados de la app, desactiva Wi-Fi/datos antes de abrir y captura
primera apertura y reapertura tras forzar detención. Los tiempos de `am start`
corresponden al arranque de actividad, no al instante exacto de mapa listo.

Resultados comprobados y [registro original](fase6-qa-record.json):

- `build/qa/a957fec/ruta-rd-PRUEBAS-a957fec.apk`: **249.294.941 bytes**.
  SHA256 del archivo y de la instalación:
  `85f227b7f1ae631d5f8606a263c5db057c377cc43ec6dda9941e56251429d0dd`.
- `pm clear com.example.ruta_rd`: Success, antes de la primera apertura.
  Wi-Fi = 0, datos = 0 y `dumpsys connectivity`: **Active default network: none**.
- [Primera apertura](fase6-primera-apertura.png): mapa nacional visible,
  sin error de carga ni pantalla vacía. Android devolvió `Status: timeout` y
  `WaitTime: 11117` para la espera de actividad debug. La captura se tomó a
  23.239 ms desde la orden de apertura; demuestra que el mapa estaba disponible
  entonces, sin medir el instante exacto en que terminó de cargar.
- Copia privada local recién creada: `rd-20261118-v2.pmtiles`, 58.474.685 bytes.
- [Reapertura tras forzar detención](fase6-reapertura.png): mapa disponible
  sin red, sin volver a descargar datos. `Status: ok`, `LaunchState: COLD`,
  `TotalTime: 10448` ms. No se hallaron `E/flutter`, `FATAL EXCEPTION` ni
  `Unhandled Exception` en el logcat de estas dos aperturas.
- Estos tiempos debug del emulador **no aceptan el rendimiento final**. Falta
  medir profile/release en el teléfono objetivo, como exige el plan.
- Se intentó primero `flutter build apk --debug` universal. La descarga de los
  motores ARM del SDK avanzaba a aproximadamente 100 KB/s; se detuvo ese intento
  y se compiló el destino x64 instalado. No hay APK ARM probado. El script elige
  ahora la arquitectura del dispositivo conectado para evitar descargas ajenas
  al destino que se está validando.

## Entrega en el emulador

Después de las pruebas se ejecutó `tools/run_android.ps1`: APK normal release
x64, instalado con Success y abierto con `Status: ok`, `LaunchState: COLD` y
`TotalTime: 3575` ms de actividad. Usa los datos privados ya preparados durante
el ensayo QA; no es otra medición de primera carga limpia. Tamaño exacto:
102.755.039 bytes. SHA256 del archivo y de la instalación:
`63e0bd5adf33c68507e01fdf57e8bb98d40d570d7b00404a8969145b4329cff9`.
El código de producción corresponde igualmente a `a957fec`; solo se añadió
documentación después. No se ejecutaron pruebas Flutter en paralelo con la
compilación final.

Con Wi-Fi y datos todavía apagados, dos toques directos cerca de Santiago y
Santo Domingo generaron automáticamente la [línea azul en la app normal](fase6-release-ruta.png).
No hay ejecutor de integración ni banner debug en la aplicación entregada.
No se detectaron excepciones fatales de Flutter o Android en ese recorrido.
Se restauraron Wi-Fi y datos a 1 y se dejó la aplicación normal abierta.
La firma sigue siendo de desarrollo, sin publicación en tiendas.

## Pendientes para aceptar

- Ejecutar la instalación limpia, primera apertura sin red y reapertura en el
  teléfono Android físico de referencia; medir allí con profile/release.
- Obtener GPS real en ese teléfono, registrar precisión y repetir permiso
  rechazado y funcionamiento sin red. No hay evidencia física nueva.
- Completar la revisión cartográfica del piloto: conexiones, cruces, barreras
  y acceso peatonal. Seguir aristas OSM no demuestra transitabilidad en terreno.
- Resolver los pendientes anteriores y registrar la aceptación antes de etiquetar.

Límites vigentes: búsqueda por nombres limitada a 190 lugares de Ciudad Colonial;
rutas peatonales sobre datos OSM, sin garantía de seguridad o accesibilidad;
componentes desconectados y ausencia de caminos producen errores explícitos.
La selección nacional incluye aguas territoriales y no garantiza un camino
cercano. El ajuste nacional admite hasta 2.500 m de acceso al grafo, separado
y sin verificar; el piloto usa 100 m. El mapa llega a zoom 15 con ampliación
visual hasta 19. No hay navegación vehicular, tráfico ni cobertura de Haití.
