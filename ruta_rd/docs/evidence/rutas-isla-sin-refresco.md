# Rutas de toda la isla y colocación inmediata de puntos

19 de noviembre de 2026. Se corrige el reporte de falta de rutas fuera de Ciudad Colonial y refresco del mapa al colocar un punto.

## Causas y correcciones

El motor inicial seguía usando el grafo piloto. Se incorporó la red peatonal OSM de RD y Haití: 3.329.523 nodos, 6.974.434 aristas dirigidas y 324.695 vías. Se empaqueta un grafo binario de 47.955.584 bytes comprimidos, SHA256 `7d66fba32c740707d0db52d14aff05bdbb2a229480ff4ea7e5040809c28b0c7f`. Fuente y límites del filtro en [preparación](../../tools/island_routing/README.md) y assets/routing/manifest.json.

La prueba Android detectó que AAPT descomprimía los assets con extensión .gz y quitaba la extensión. Se cambió a island-walking.rdi y se excluyó ese formato de recompresión. Se inspeccionó el APK: contiene el recurso con el nombre esperado y 47.955.584 bytes, sin modificaciones.

Las rutas fuera del piloto usan A* con índice espacial y cola de prioridad en un isolate persistente. La interfaz permanece libre durante la carga inicial y los cálculos. Se descartan resultados obsoletos si cambian los puntos. El motor piloto mantiene los recorridos locales ya probados.

El refresco tenía dos causas: el bloque condicional de instrucciones cambiaba la posición e identidad del mapa al terminar la selección; además se creaban de nuevo proveedores y capas del mapa base. Se conserva la clave del mapa, se reserva el espacio de instrucciones y se reutiliza la misma capa vectorial y sus cachés. Una capa de gestos coloca el punto al soltar un toque sin esperar el reconocimiento de doble toque de la cartografía. No se cambia la cámara al colocar puntos manuales. Los controles del mapa permanecen encima de esa capa.

Los puntos de la vista general se ajustan a nodos hasta 2.500 m. Las aproximaciones siguen separadas y dibujadas en naranja como accesos no verificados; la distancia del recorrido solo suma aristas reales. Los puntos sin un camino próximo o sin conexión siguen devolviendo errores explícitos.

## Verificación

- Formato aplicado; flutter analyze sin problemas; 27 pruebas aprobadas.
- Regresión: al avanzar un solo fotograma de 16 ms después del toque, el marcador ya existe y conserva la identidad del mapa, su posición en pantalla, centro y zoom. Es una comprobación de respuesta de la interfaz; no una medición de latencia física de pantalla.
- A*: pesos, direcciones, desconexión, origen igual a destino, archivos inválidos, cobertura y distancia máxima de acceso.
- Cuatro recorridos reales: se verificó cada segmento contra una arista dirigida del grafo y la suma de sus pesos contra la distancia final. No basta con comparar la longitud geométrica de una línea.

| Recorrido | Distancia sobre grafo | Vértices | Cálculo en pruebas de escritorio |
|---|---:|---:|---:|
| Santiago → Puerto Plata | 56.808 m | 1.508 | 169 ms |
| Santo Domingo → Punta Cana | 186.712 m | 2.489 | 221 ms |
| Puerto Príncipe → Les Cayes | 193.906 m | 4.176 | 252 ms |
| Puntos manuales Haití → RD de la prueba anterior | 449.727 m | 13.337 | 1.018 ms |

Los puntos del último caso son 19.13076, -72.39464 y 19.00110, -69.68510, con accesos separados de 936 m y 1.890 m. Los tiempos anteriores corresponden solo al cálculo sobre un grafo ya abierto en el equipo de desarrollo; no son tiempos de carga inicial ni medidas de un teléfono físico.

Prueba Android: `flutter test integration_test/island_routing_test.dart -d emulator-5554` aprobada en Pixel_10a con Wi-Fi y datos móviles apagados. Se verificaron ambos marcadores al siguiente fotograma, la identidad del mapa y de la capa vectorial, la conservación de centro y zoom, el botón Calcular ruta y Borrar ruta conservando puntos. El recorrido Haití → RD resultó en 449.726,500 m y 13.337 vértices. El primer cálculo debug, incluida apertura, descompresión e indexación del grafo, tardó 4.737,37 ms según el controlador.

Entrega final completada: `tools/run_android.ps1` compiló el APK release x64 de demostración (172,3 MB), instaló con Success y abrió la aplicación normal en Pixel_10a con Status ok. Android reportó 4.224 ms de arranque de actividad; ese valor no mide la carga del grafo de rutas. Se verificó por SHA256 que el recurso island-walking.rdi dentro del APK coincide exactamente con el manifiesto.

Con Wi-Fi y datos móviles apagados se colocaron manualmente origen 19.13400, -72.39464 y destino 19.00434, -69.68510. La versión normal calculó y dibujó 449.727 m sobre caminos, mostrando por separado accesos de 578 m y 2.158 m. [Captura real de la versión release](isla-ruta-release.png). No se encontraron FATAL EXCEPTION, E/flutter o Unhandled Exception en los registros del proceso durante esta comprobación. Se restauraron ambas conexiones a su estado original y se dejó la aplicación normal abierta con el recorrido.

La revisión cartográfica en campo y el rendimiento en un dispositivo físico siguen pendientes. Las rutas son peatonales; no incluyen tráfico ni navegación para vehículos.
