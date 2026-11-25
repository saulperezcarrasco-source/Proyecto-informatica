# Contratos iniciales

GNSS 1.5.1: GpsLocationService.watch comprueba permisos y abre un stream
cancelable sin consulta puntual previa. En Android recibe GPS_PROVIDER mediante
EventChannel `ruta_rd/gnss`, 1 s / 0 m; la última cancelación libera el proveedor.
Ubicación aproximada produce precisePermissionRequired para navegación. La
consulta puntual conserva timeout propio. Pausar/volver respeta la pausa manual;
la antigüedad y precisión de cada fix se validan antes de avanzar sobre la ruta.

Ampliación 1.3: TravelMode (walking, bicycle, car, motorcycle) selecciona el
grafo y una velocidad media de referencia. RouteResult.mode es walking por
defecto para conservar fixtures/piloto; los perfiles nacionales lo propagan.
HomeController.setTravelMode conserva A/B, invalida resultados obsoletos,
libera el worker previo y recalcula en un único grafo activo. El piloto se
usa solo a pie. Cada grafo RDI2 añade una tabla de triples de giro prohibido;
A* conserva el estado de arista entrante para resolver alternativas legales.
Las restricciones temporales de sentido se evitan en preparación, sin servicios
remotos en ejecución. La ruta minimiza distancia; ETA no considera tráfico.
La revisión 3 del catálogo conserva IDs/versiones y añade locales OSM sin nombre
con descripciones explícitas de categoría, además de nombres de operador.

Ampliación 1.1.0: LocationReading añade heading y timestamp opcionales;
LocationService.watch devuelve un Stream de lecturas y por defecto un error
unavailable para servicios que solo admiten consulta puntual. GpsPlatform.watch
es inyectable; el adaptador Android usa LocationManager, filtro de 2 m e intervalo
solicitado de 1 s. Las cadencias reales dependen de Android/GPS. No cambia locate.
NavigationController.start/stop/dispose controla la suscripción y publica posición,
rumbo y remainingMeters. Descarta lecturas inválidas, viejas o fuera de RD;
lecturas de precisión >35 m no desplazan la flecha ni hacen avanzar. Fuera de ruta conserva progreso
y ofrece recalcular explícitamente desde GPS. RouteResult original es inmutable.

Ampliación 1.2.0: RouteProgress indexa segmentos en celdas de 0,002 grados.
La proyección respeta una ventana de continuidad para evitar saltos a tramos
futuros en cruces y admite retrocesos reales, que aumentan la distancia restante.
Incluye las aproximaciones reales a A/B en el progreso sin convertirlas en
caminos verificados. Rechaza lecturas futuras, fuera de orden y desplazamientos
imposibles con timestamp. formatDistance usa metros por debajo de 1.000 y km
con un decimal desde ese umbral, omitiendo .0.

NationalSearch expone PlaceCatalog, construido en el worker con celdas de 0,01
grados. La búsqueda combina palabras del nombre/alias y contexto de proximidad
a una ciudad OSM hasta 25 km; esa proximidad no representa una dirección postal.
El mapa consulta solo las celdas visibles: turismo desde zoom 14, otros locales
desde 15; máximo 160 candidatos y 45 etiquetas pintadas con colisiones evitadas.
Las calles/barrios siguen etiquetados por las teselas. Una etiqueta se puede
seleccionar como A/B; con ambos elegidos abre opciones de origen/destino.
Los IDs y versión de favoritos se conservan en la revisión 2 del catálogo.
En empates de coincidencia se prioriza el nombre principal sobre los alias de
dirección/ciudad; el nombre normalizado e ID resuelven los empates restantes.

NationalSearch.load/search/dispose conserva un isolate y devuelve Place actuales;
mínimo dos caracteres, hasta 15 resultados nacionales, IDs OSM estables prefijados
rd:. HomeController combina con hasta diez resultados piloto y limita a veinte,
con debounce y descarte por consulta vigente. Los favoritos nacionales referencian
dominican-search/2026-11-18; los existentes del piloto conservan región/versión.

Los modelos Dart están en `lib/core/models/models.dart`. Coordinate utiliza grados decimales `lat` y `lon`; RegionBounds define sur, oeste, norte y este. GeoJSON usa `[longitud, latitud]` y requiere conversión explícita.

RegionManifest contiene identificación, versión, límites, fuente, atribución, fecha de generación e indicador de demostración. Place contiene identificación, nombre, categoría, coordenada y alias opcionales. GraphNode identifica un punto y GraphEdge conecta dos IDs con distancia en metros. Las aristas son dirigidas: un tramo bidireccional necesita dos. RoutingGraph agrupa nodos y aristas.

RouteResult contiene coordenadas, distancia sobre el grafo en metros, tiempo estimado en minutos y distancias de aproximación separadas. RouteFailure distingue punto inválido, fuera de cobertura, distancia excesiva al grafo, desconexión y datos inválidos. Estos modelos definen datos; la validación se implementará al cargar y calcular.

Servicios previstos: `loadRegion()`, `searchPlaces(query)`, `calculateRoute(origin, destination)` y `getCurrentLocation()`. Sus firmas concretas y resultados tipados se definirán antes de cada integración. El motor de rutas no importará Flutter ni geolocator.

Estados previstos: región `loading`, `ready`, `error`; ubicación `idle`, `locating`, `success`, `failure`; ruta `idle`, `calculating`, `success`, `failure`. Cambiar origen o destino elimina la ruta anterior.

Fase 3: `searchPlaces(places, query)` es una función Dart pura que devuelve como máximo diez lugares locales. El orden es rango de coincidencia, nombre normalizado e ID. `HomeController.selection` activa explícitamente origen o destino para tocar el mapa; `cancelSelection()` termina ese modo. Solo las selecciones dentro de `islandBounds` actualizan puntos y `focusedPoint`; una revisión numérica permite centrar también al cambiar origen cuando ya existe destino. Los puntos manuales mantienen el zoom para permitir elegir el segundo punto en otra parte de la isla. Los puntos inválidos conservan la selección anterior y el modo de selección activo.

Fase 4: RoutingService acepta `maxApproach` (100 m) y cobertura opcional; en producción se aplica `pilotBounds`. calculateRoute devuelve RouteResult o lanza RouteFailure. HomeController conserva `routeFailure` para errores tipados y descarta solicitudes obsoletas al cambiar puntos o borrar. clearRoute conserva puntos; clear elimina todo. La duración medida queda en calculationMilliseconds para las pruebas, sin confundirla con el tiempo de caminata estimado.

Ampliación de isla: `IslandRoutingService.calculate(start,end)` devuelve `Future<RouteResult>` y ejecuta la carga y A* en un isolate persistente. Se utiliza cuando al menos uno de los puntos queda fuera del piloto; conserva el contrato RouteResult/RouteFailure. IslandGraph valida `islandBounds` y busca nodos hasta 2.500 m del punto; distancias de acceso se indican por separado. Los componentes sin conexión y puntos sin caminos próximos no producen rutas simuladas. El cálculo tiene una espera acotada y sus resultados se descartan al cambiar puntos o disponer el controlador. La búsqueda por nombre sigue siendo piloto.

Trazado automático: las selecciones de usuario por mapa, búsqueda y GPS pasan por `selectAndRoute`. El marcador se actualiza de inmediato; si existen ambos puntos se programa el cálculo en una microtarea. Varias ediciones en el mismo turno solo calculan la última selección válida. `select` conserva su contrato de actualización sin cálculo para uso interno. Cambiar cualquiera de los puntos elimina el trazado anterior y calcula el nuevo. Borrar ruta conserva los puntos sin volver a calcular hasta que cambien o se pulse el botón manual. El mapa muestra progreso y errores de ruta sobre la cartografía, sin modificar el espacio de la cámara.

Fase 5: LocationReading contiene coordenada, precisión en metros y approximate; valida valores geográficos finitos y precisión no negativa. LocationException contiene un LocationFailure tipado. LocationService mantiene getCurrentLocation; GpsPlatform permite simular la frontera nativa en pruebas. El adaptador limita la obtención de posición a 15 segundos. HomeController mantiene locationFailure separada de los errores de rutas, accuracy y approximateLocation; una revisión independiente descarta lecturas GPS obsoletas al elegir un origen manual, cancelar, limpiar o disponer. Los fallos conservan los puntos y el trazado anterior. No se consulta GPS en la carga inicial ni en segundo plano.

Restricción posterior a RD: dominicanBounds e inDominicanRepublic sustituyen islandBounds y la selección rectangular de La Española. El grafo también está recortado al límite nacional por nodos y segmentos. mapPoint asigna A si falta origen y B si falta destino, salvo que exista un modo de reemplazo explícito. Cuando ambos puntos existen y no se ha elegido reemplazo, tocar el mapa no los modifica. Dos toques directos disparan el cálculo automático; las actualizaciones posteriores y cancelaciones conservan sus contratos.

Preparación de fase 7: `RegionData` añade `manifest` obligatorio, cargado desde
el manifest.json real mediante `RegionRepository`. Expone RegionManifest (ID,
versión y procedencia) para referenciar datos persistidos sin copiar los lugares.
Se validan campos de texto y fecha durante la carga; un fallo sigue el error de
carga existente. No cambian Place, los motores de rutas ni sus contratos.

Favoritos de fase 7: Favorite guarda placeId, regionId y regionVersion. La
identidad es región + ID, de modo que un cambio de versión no duplica el lugar.
FavoriteRepository.load/save es asíncrono e inyectable; LocalFavoriteRepository
usa la clave independiente ruta_rd.favorites.v1 con esquema JSON 1. Rechaza
datos corruptos sin borrarlos y deduplica referencias al cargar.
FavoritesController serializa operaciones, publica busy/ready/error/invalidData
y actualiza su lista solo tras persistir correctamente. reset requiere
confirmación del usuario en FavoritesPanel. Un fallo de escritura conserva la
lista anterior. El panel resuelve referencias contra los Place actuales de la
región: los IDs eliminados u otra región se muestran no disponibles y solo
permiten quitarse. La selección utiliza el Place actual, no coordenadas guardadas.
HomeScreen conserva el único HomeController del mapa; guardar o quitar favoritos
no modifica puntos, consulta o ruta. No se añaden dependencias ni servicios.
