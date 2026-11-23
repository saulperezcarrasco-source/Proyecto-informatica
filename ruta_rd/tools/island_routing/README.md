# Red peatonal offline de La Española

Este generador ahora produce un **intermedio de preparación** en tools/island_routing/cache, no un asset de la aplicación. El APK incluye únicamente el recorte de República Dominicana generado con [dominican_region](../dominican_region/README.md).

Fuente fija: [Geofabrik, extracto OSM del 18/11/2026](https://download.geofabrik.de/central-america/haiti-and-domrep-261118.osm.pbf). Atribución: © OpenStreetMap contributors, ODbL 1.0. El archivo fuente, el entorno de preparación y el intermedio están excluidos de Git; solo el recorte nacional posterior se incluye en assets/routing.

Preparación: usar Python 3.13 con `pip install osmium==4.3.0`, guardar el extracto como `source.osm.pbf` junto a `prepare.py` y ejecutar `python prepare.py`. En este equipo se preparó un entorno Python 3.13.9 embebido dentro de esta carpeta; no es una dependencia de la aplicación Android. La fuente verificada tiene SHA256 `649b91a2e737e6d6f1b7588eb598d88e4e262f1cce3119a9b97dadf5172734f6`.

El generador usa IDs de nodos OSM, no deduce conexiones entre cruces visuales. Conserva cada punto de forma y la dirección peatonal, filtra acceso restringido y caminos en construcción; los detalles y límites del filtro quedan en el manifiesto. No agrega enlaces artificiales entre componentes desconectados.

Formato RDI1 little endian, comprimido con gzip determinista:

El archivo usa extensión `.rdi` y se excluye de recompresión Android. No usar `.gz`: AAPT descomprime esos assets y elimina esa extensión, haciendo que la ruta pedida por Flutter deje de existir en el APK.

1. Cabecera: ASCII RDI1, uint32 N (nodos), uint32 M (aristas dirigidas).
2. N pares int32 latitud/longitud en grados × 10⁷.
3. N+1 offsets uint32 del índice de adyacencia CSR.
4. M destinos uint32 y M pesos float32 en metros.
5. N identificadores uint32 de componentes débilmente conexos.

El peso de cada tramo es su distancia geodésica, redondeada hacia arriba al centímetro. El lector comprueba longitud, límites, offsets, destinos y pesos. Construye una cuadrícula espacial y usa A* con una cota geodésica conservadora y una cola de prioridad. El grafo permanece en un isolate; ni descompresión, indexación ni búsquedas largas bloquean el hilo de interfaz. Los assets se cargan al primer cálculo fuera del piloto y se reutilizan después.

Se conserva el motor piloto para recorridos con ambos puntos en Ciudad Colonial. Fuera de ese sector se usa la red de toda la isla. La aproximación máxima a un nodo del grafo es 2.500 m para permitir selección desde la vista general; esos accesos se muestran por separado en naranja y no se consideran caminos verificados. Un punto sin caminos próximos o sin conexión devuelve un error, nunca una línea ficticia. No se incluyen ferris ni información en tiempo real de fronteras o transitabilidad. La revisión cartográfica en campo sigue pendiente.
