# Cobertura exclusiva de República Dominicana

El límite proviene de [OSM, relación nacional 307828](https://www.openstreetmap.org/relation/307828), obtenido mediante [la API de OSM](https://api.openstreetmap.org/api/0.6/relation/307828/full). Las propiedades del GeoJSON generado incluyen versión, fecha y SHA256 de esa descarga. Atribución y licencia: © OpenStreetMap contributors, ODbL 1.0.

Preparación reproducible, Python 3.13:

1. Instalar `requirements.txt` en el entorno de preparación.
2. Guardar la respuesta de la API como `boundary.osm` en esta carpeta. El archivo fuente y sus metadatos de edición no se empaquetan en Android.
3. Ejecutar `tools/island_routing/prepare.py` con su fuente Geofabrik fijada. El grafo intermedio queda en tools/island_routing/cache, excluido de Git y de los assets Android.
4. Ejecutar `tools/dominican_region/prepare.py`. Ensambla la relación OSM como polígono, genera assets/national/dominican-republic.geojson y lib/core/dominican_boundary.dart, y recorta el grafo a assets/routing/dominican-walking.rdi.
5. Ejecutar tools/national_map/prepare.ps1 para el archivo PMTiles del encuadre de RD. Durante esta modificación se extrajeron localmente esas teselas del archivo anterior; el resultado mantiene el mismo contenido y checksum del extracto de RD.

Se eliminan nodos fuera del límite nacional y aristas cuyo segmento completo no esté cubierto por él. Luego se reconstruyen IDs, offsets y componentes; no se conservan conexiones a través de Haití ni se añaden enlaces artificiales. El formato binario RDI1 y los filtros peatonales anteriores se mantienen. El manifiesto de rutas registra estadísticas y checksum del recorte.

La vista y el área de selección utilizan el límite nacional, además de los límites de visualización. Una máscara oculta los países vecinos presentes en teselas compartidas de frontera. NationalMapArchive añade un filtro within a los símbolos para excluir sus etiquetas completas antes de dibujar, evitando fragmentos cortados en el borde. El límite administrativo incluye aguas territoriales; seleccionar un punto no garantiza que esté sobre un camino transitable. El motor mantiene los accesos no verificados y errores explícitos si no hay conexión.
