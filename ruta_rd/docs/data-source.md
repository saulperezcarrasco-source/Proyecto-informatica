# Fuente y preparación de datos

La visualización nacional añadida por solicitud del usuario utiliza el paquete Protomaps/OSM local documentado en `assets/national/manifest.json` y `docs/evidence/tema-y-mapa-nacional.md`. La siguiente preparación se refiere al grafo e índice de búsqueda de la zona piloto, cuya cobertura se conserva.

Extracto descargado el 19 de noviembre de 2026 desde la API oficial de OpenStreetMap, bbox oeste -69.8900, sur 18.4700, este -69.8800, norte 18.4780. Original incluido en `tools/prepare_region/source.osm`.

Fuente: https://api.openstreetmap.org/api/0.6/map?bbox=-69.8900,18.4700,-69.8800,18.4780

Datos © OpenStreetMap contributors. Licencia de la base original y derivada: ODbL 1.0. Condiciones: https://www.openstreetmap.org/copyright y https://opendatacommons.org/licenses/odbl/1-0/ . Los JSON derivados y el original se distribuyen junto al código para permitir regenerarlos.

Desde la raíz de ruta_rd, ejecutar `powershell -ExecutionPolicy Bypass -File tools/prepare_region/prepare.ps1`. Se generan manifest, GeoJSON de tramos, lugares y grafo. El mapa dibuja únicamente geometrías locales, sin TileLayer ni descarga inicial.

Reglas iniciales: conserva exclusivamente pares de nodos consecutivos dentro de cobertura; no une cruces visuales ni recorta creando conexiones. Excluye foot=no/private, access=no/private salvo permiso peatonal explícito; excluye nodos con barreras salvo foot=yes. Incluye escaleras: no se afirma accesibilidad. Respeta oneway:foot; el sentido vehicular no determina el peatonal. Las reglas son conservadoras y requieren revisar casos ambiguos.

Se añadieron polígonos cerrados contenidos en la cobertura y un informe `validation.json` de componentes débiles: 413, 8, 6, 5, 4 y 3 nodos. El motor informa desconexión al no hallar ruta dirigida. Pendiente: barreras con otras etiquetas, restricciones de relaciones, categorías de lugares, lugares de vías/relaciones y revisión independiente de cinco lugares y cinco conexiones. Las rutas se pueden demostrar, pero falta la aceptación cartográfica final.
