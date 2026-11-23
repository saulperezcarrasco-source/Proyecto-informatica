# Línea azul al colocar origen y destino

19 de noviembre de 2026. Reporte: al colocar punto a punto no se dibuja la línea azul.

La versión anterior requería pulsar Calcular ruta, situado debajo del mapa. Ahora la selección de usuario desde el mapa, búsqueda o GPS inicia el cálculo cuando existen ambos puntos. Cambiar origen o destino vuelve a calcular; el marcador se coloca antes de comenzar el trabajo asíncrono. Se descartan selecciones pendientes que hayan sido reemplazadas en la misma microtarea y los resultados obsoletos siguen protegidos por la revisión del cálculo.

Durante el cálculo se muestra Trazando ruta… sobre la cartografía. Los errores por falta de caminos o conexión se muestran en el mismo lugar; no es necesario desplazarse hasta el panel inferior para verlos. No se dibujan líneas ficticias cuando no existe ruta.

Formato aplicado y análisis limpio. 28 pruebas aprobadas, incluida selección automática A→B, cambio de ambos puntos, puntos coincidentes y cancelación al limpiar. Se mantienen las pruebas de respuesta inmediata de marcadores y de aristas OSM reales.

Prueba Android aprobada: `flutter test integration_test/island_routing_test.dart -d emulator-5554`, Pixel_10a con Wi-Fi y datos móviles apagados. Se colocaron A y B mediante toques sobre el mapa, sin pulsar Calcular ruta. El resultado automático fue 449.726,500 m con 13.337 vértices. Se comprobó que PolylineLayer contiene la línea azul de esas coordenadas y que el mapa y su capa base mantienen su identidad. El primer cálculo debug, incluida apertura del grafo, reportó 7.374,198 ms; no es una medida de rendimiento físico. Un segundo toque para cambiar el destino produjo una nueva ruta más corta automáticamente; Borrar ruta conservó los puntos.

Entrega normal completada: APK release x64 de demostración, 172,3 MB, instalado con Success y abierto con Status ok en Pixel_10a. El arranque de actividad reportado por Android fue de 2.608 ms (no mide el tiempo del cálculo).

Se repitió la selección manual A en Haití y B en RD en la versión normal con Wi-Fi y datos apagados: la línea azul apareció automáticamente, sin tocar Calcular ruta ni desplazarse al panel inferior. [Captura de la ruta automática](ruta-automatica-release.png). No se encontraron excepciones fatales de la aplicación en logcat durante esa comprobación. Se restauraron ambas conexiones y se dejó el recorrido abierto.
