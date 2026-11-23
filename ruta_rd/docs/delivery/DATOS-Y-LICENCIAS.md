# Datos, origen y límites de la demostración

La cartografía de la aplicación es local y corresponde a **República Dominicana**.
Haití se excluye de la selección, del grafo distribuido y de la vista mediante
el límite nacional OSM 307828. La búsqueda comprende **96.873 registros OSM
nacionales más 190 lugares del piloto**; no cubre todas las direcciones del país.
La selección manual y las rutas usan la red nacional incluida.

Fuentes y licencias registradas en los manifiestos distribuidos:

- OpenStreetMap, © OpenStreetMap contributors, [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
  Piloto obtenido mediante [OSM API](https://api.openstreetmap.org/api/0.6/map?bbox=-69.8900,18.4700,-69.8800,18.4780).
- Cartografía PMTiles de [Protomaps, 18/11/2026](https://build.protomaps.com/20261118.pmtiles),
  tileset 4.15.2 y estilo 5.7.2. Licencia del estilo copiada en LICENCIA-ESTILO.txt.
  Natural Earth: dominio público, según el manifiesto del mapa.
- Grafo nacional derivado del [extracto Geofabrik del 18/11/2026](https://download.geofabrik.de/central-america/haiti-and-domrep-261118.osm.pbf),
  recortado al límite RD: 1.546.484 nodos y 3.329.274 aristas dirigidas.
  Límite OSM relación 307828, versión 149. Atribución OSM/ODbL.

Los archivos datos-mapa.json, datos-rutas.json y datos-piloto.json conservan
procedencia, fechas, hashes y atribuciones. El código fuente contiene los
assets derivados y scripts de preparación. Las atribuciones se muestran en el
mapa. Flutter incorpora sus avisos de licencias de dependencias en el APK.

Las rutas minimizan distancia en el grafo disponible de **a pie, bici, coche o
moto**; no representan tráfico, seguridad, accesibilidad ni verificación en campo.
Respetar una conexión OSM no certifica su estado actual en terreno. Los pasos
sin conexión no se unen artificialmente. La comparación de cinco lugares y
cinco conexiones contra OSM y las pruebas de recorridos están en las evidencias.

Los accesos al grafo se muestran separados y no están verificados en terreno:
hasta 100 m en el piloto y 2.500 m en el motor nacional. La cobertura nacional
incluye aguas territoriales: poder marcar un punto no garantiza un camino cercano.
Teselas hasta zoom 15 con ampliación visual hasta 19; las calles y lugares de
OSM pueden estar incompletos o desactualizados. Los tiempos de caminata son
estimaciones, no tiempos medidos en un trayecto real.

No hay backend, servicios cartográficos remotos ni descargas durante el uso.
Favoritos y tema se guardan localmente. Los ensayos usan un emulador: las
posiciones GPS inyectadas están identificadas como simuladas y no se afirma
recepción satelital ni rendimiento de un teléfono físico. La firma Android Debug
identifica una demostración, no una versión preparada para Google Play.
# Catálogo nacional de búsqueda (1.3.0-demo)

96.873 registros de nodos, vías y áreas OSM del extracto Geofabrik
del 18/11/2026, recortados al límite de RD. Incluye 50.184 tramos de calles,
5.554 registros de lugares/barrios/áreas y categorías de negocios/turismo.
Incluye 1.635 servicios/locales sin nombre registrado, indicados por categoría
y “(sin nombre)”. No son negocios únicos ni una lista completa de lugares.
Fuente, SHA256, conteos y licencia ODbL 1.0 en assets/search/manifest.json.
© OpenStreetMap contributors. No se incluyen datos extraídos de Google Maps.
Los grafos RDI2 añaden filtros de acceso/sentido por perfil y giros con vía
entrante/nodo/vía saliente; las restricciones complejas via-way se evitan.
Las direcciones temporales se excluyen sin asumir horarios. Detalles, conteos y
SHA en manifest-bicycle/motorcar/motorcycle.json. Preparación reproducible en
tools/dominican_region/mobility.py. Referencias OSM:
[acceso](https://wiki.openstreetmap.org/wiki/Key:access),
[sentido](https://wiki.openstreetmap.org/wiki/Key:oneway) y
[giros](https://wiki.openstreetmap.org/wiki/Relation:restriction).
Esto no certifica condiciones reales ni incluye todos los regímenes legales.
