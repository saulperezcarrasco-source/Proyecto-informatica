# Contratos iniciales

Los modelos Dart están en `lib/core/models/models.dart`. Coordinate utiliza grados decimales `lat` y `lon`; RegionBounds define sur, oeste, norte y este. GeoJSON usa `[longitud, latitud]` y requiere conversión explícita.

RegionManifest contiene identificación, versión, límites, fuente, atribución, fecha de generación e indicador de demostración. Place contiene identificación, nombre, categoría, coordenada y alias opcionales. GraphNode identifica un punto y GraphEdge conecta dos IDs con distancia en metros. Las aristas son dirigidas: un tramo bidireccional necesita dos. RoutingGraph agrupa nodos y aristas.

RouteResult contiene coordenadas, distancia sobre el grafo en metros, tiempo estimado en minutos y distancias de aproximación separadas. RouteFailure distingue punto inválido, fuera de cobertura, distancia excesiva al grafo, desconexión y datos inválidos. Estos modelos definen datos; la validación se implementará al cargar y calcular.

Servicios previstos: `loadRegion()`, `searchPlaces(query)`, `calculateRoute(origin, destination)` y `getCurrentLocation()`. Sus firmas concretas y resultados tipados se definirán antes de cada integración. El motor de rutas no importará Flutter ni geolocator.

Estados previstos: región `loading`, `ready`, `error`; ubicación `idle`, `locating`, `success`, `failure`; ruta `idle`, `calculating`, `success`, `failure`. Cambiar origen o destino elimina la ruta anterior.
