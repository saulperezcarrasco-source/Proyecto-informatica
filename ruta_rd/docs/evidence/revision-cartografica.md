# Cierre de revisión de fuente cartográfica — 20/11/2026

Se contrastaron cinco lugares y cinco conexiones del piloto con la API actual
de OpenStreetMap. El [informe de comparación](revision-cartografica.json)
conserva IDs, versiones, coordenadas, extremos, etiquetas y fecha UTC.
No hubo discrepancias. También se contrastaron con el extracto original los
439 nodos, 190 lugares y 1.046 aristas dirigidas del piloto.

Lugares revisados: Café Conde de Peñalba (2020747192, v4), Museo Infantil
Trampolín (3306069214, v1), Café Santo Domingo (7222791985, v1), Café La
Moricette (7241829266, v1) y Cafeteria Sabor Real (11049698105, v1).
Los nombres y las coordenadas coinciden con los assets.

Conexiones revisadas: Avenida del Puerto (ways 28017889 v24 y 28017891 v34),
Plaza de la Hispanidad (28101420 v13), Calle Isabel La Católica (28101949 v30)
y Calle Hostos (28101951 v22). Los pares del informe son nodos consecutivos
de cada vía actual, tienen las mismas coordenadas que el grafo y corresponden
a aristas permitidas. Se consultaron además sus diez extremos en la API.

Se revisaron las reglas del importador: excluye foot=no/private y access=no/private
sin autorización peatonal explícita; excluye nodos con barrera sin foot=yes;
incluye escaleras sin prometer accesibilidad. El sentido vehicular oneway no
restringe caminar; se respeta oneway:foot. Las aristas conectan IDs consecutivos
OSM; no unen cruces visuales ni componentes por proximidad. Los seis componentes
del piloto (413, 8, 6, 5, 4 y 3 nodos) permanecen separados deliberadamente.

Fuentes consultadas: [cinco lugares](https://api.openstreetmap.org/api/0.6/nodes?nodes=7222791985,7241829266,11049698105,2020747192,3306069214)
y [cinco vías](https://api.openstreetmap.org/api/0.6/ways?ways=28017889,28017891,28101420,28101949,28101951).
El informe enlaza cada objeto. Se conserva el SHA256 del extracto original.

Esta revisión satisface la comparación contra fuente de fase 2 y se suma a los
diez pares y las pruebas offline de fase 6. Es una revisión de datos OSM y de
conectividad; no certifica seguridad, accesibilidad ni estado físico de caminos.
La búsqueda por nombre sigue limitada al piloto. La extensión nacional cuenta
con el recorte de RD y los ocho recorridos comprobados de fase 6, sin afirmar
una inspección en terreno de todas las calles del país.
