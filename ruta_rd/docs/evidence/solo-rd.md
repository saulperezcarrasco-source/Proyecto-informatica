# República Dominicana y rutas automáticas con dos toques

19 de noviembre de 2026. Solicitud: excluir Haití y calcular la ruta automáticamente al agregar A y B.

La vista inicial encuadra RD y el botón indica Ver toda RD. El límite nacional OSM 307828 determina la selección manual/GPS y la máscara de cartografía. No se utiliza un corte por longitud, que dejaría partes de Haití dentro de la selección.

Se sustituyó el mapa anterior de 112.126.532 bytes por el extracto de RD de 58.474.685 bytes. Las teselas compartidas de frontera se enmascaran con el polígono nacional para ocultar cartografía de países vecinos. Además se filtran geográficamente las capas de símbolos con within antes de dibujarlas, evitando que queden fragmentos de etiquetas extranjeras dentro de la máscara. Al abrir el archivo nuevo se retira la copia privada antigua de Hispaniola.

El grafo se recortó tanto por nodos como por segmentos completos y se reconstruyeron sus componentes: 1.546.484 nodos, 3.329.274 aristas dirigidas y 23.363.218 bytes comprimidos. SHA256 `7c6f3640d014f977a27dc1396e2fe11a7990b48ba5dd7e666bea963189341d19`. El APK ya no incluye el grafo anterior de Haití/RD. [Fuente y preparación](../../tools/dominican_region/README.md).

Dos toques directos en el mapa colocan A y B, y el cálculo comienza solo. Los botones de origen/destino permiten reemplazarlos. Los marcadores siguen apareciendo antes del cálculo y no reinician la cartografía. El aviso Trazando ruta… muestra el progreso y los fallos conservan un mensaje explícito, sin líneas ficticias.

Verificaciones realizadas:

- Formato aplicado, análisis limpio y 36 pruebas aprobadas.
- Selección válida en Dajabón, Barahona, Santiago y Punta Cana; rechazo de Puerto Príncipe, Ouanaminthe y otro punto de Haití dentro del rectángulo del mapa, sin borrar la selección anterior.
- Recorridos comprobados contra aristas OSM y con todos sus vértices dentro del límite nacional: Santiago–Puerto Plata (56.808 m), Santo Domingo–Punta Cana (186.712 m), Barahona–Santo Domingo (192.493 m) y Dajabón–Santiago (130.284 m).
- Prueba Android aprobada con Wi-Fi y datos apagados: dos toques directos, sin seleccionar modos ni pulsar Calcular ruta, generaron Dajabón–Santiago (130.283,870 m y 2.342 vértices). Primer cálculo debug con apertura del grafo: 1.753,804 ms. Se verificaron línea azul, marcadores al siguiente fotograma, identidad de la cartografía y recálculo al reemplazar el destino. Este tiempo no es una medida de un teléfono físico.
- La inspección del APK confirmó que solo se empaquetan dominican-republic.pmtiles y dominican-walking.rdi como archivos de mapa/rutas, sin los archivos anteriores de Hispaniola.
- Entrega final: APK release x64 de demostración de 98,0 MB (antes 172,3 MB), instalado con Success y abierto con Status ok. Android reportó 2.980 ms de inicio de actividad; no es el tiempo de cálculo de la ruta. [Vista nacional sin Haití ni etiquetas extranjeras](solo-rd-mapa.png).
- En la versión normal se tocaron directamente 19.44190, -70.70271 y 18.48580, -69.91868, cerca de Santiago y Santo Domingo. Sin tocar selectores ni Calcular ruta, se obtuvo una línea azul de 173.510 m con accesos separados de 39 m y 23 m. [Vista de RD y ruta](solo-rd-ruta.png), [resumen del recorrido](solo-rd-recorrido.png).
- Esta comprobación se realizó con Wi-Fi y datos móviles apagados. No se encontraron excepciones fatales de la aplicación en logcat. Se restauraron ambas conexiones y se dejó la aplicación normal abierta con la vista nacional y el recorrido.

La búsqueda por nombres sigue limitada a Ciudad Colonial. Las rutas son peatonales, y las revisiones cartográficas y físicas pendientes de fases anteriores se conservan.
