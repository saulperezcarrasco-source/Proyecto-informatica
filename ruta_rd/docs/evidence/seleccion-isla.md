# Selección en toda la isla de Santo Domingo

Esta evidencia corresponde a la primera ampliación de selección. La limitación del cálculo a Ciudad Colonial descrita aquí fue resuelta en la entrega posterior: [rutas de toda la isla y puntos inmediatos](rutas-isla-sin-refresco.md).

19 de noviembre de 2026. Solicitud: mostrar solo la isla y permitir origen y destino fuera del pequeño sector de Ciudad Colonial.

Se interpreta isla de Santo Domingo como La Española (República Dominicana y Haití). La vista inicial y el botón Ver toda la isla encuadran ese territorio; una máscara oculta los mapas de los países vecinos y el centro de cámara queda limitado al área. No es un filtro de tierra firme: el rectángulo incluye aguas costeras.

La selección manual y GPS ahora valida un área independiente del grafo. Ambos puntos se conservan en toda la isla, se pueden reemplazar y el botón de encuadre permite verlos juntos. Al elegir un punto manual se mantiene el zoom actual, facilitando elegir el siguiente en otro extremo. Se eliminó el rectángulo piloto del mapa. Fuera de los límites de la isla o ante coordenadas no finitas se conserva el punto anterior.

El extracto PMTiles se amplió al oeste para incluir Haití y funciona desde assets sin conexión. La nueva versión utiliza un archivo privado diferente al del extracto de RD para evitar reutilizar datos antiguos. Fuente y hash en assets/national/manifest.json; preparación en tools/national_map/prepare.ps1.

El cálculo de rutas y la búsqueda por nombres mantienen sus datos de Ciudad Colonial. Seleccionar puntos externos muestra esa limitación; intentar calcular no borra los puntos ni dibuja una línea simulada como si fuera una ruta.

Verificación completada:

- `dart format`: aplicado; `flutter analyze`: sin problemas; `flutter test`: 23 pruebas aprobadas. Se comprueba selección en Puerto Príncipe, Les Cayes, Cabo Haitiano, Santiago y Punta Cana; rechazo de Cuba, Puerto Rico y coordenadas no finitas sin borrar puntos anteriores; conservación de puntos ante falta de grafo. Las pruebas anteriores de rutas, carga e interfaz también pasan.
- Lectura de teselas PMTiles sin cliente de red en ocho localidades de ambos países, incluidas Puerto Príncipe, Les Cayes y Cabo Haitiano. Archivo de 112.126.532 bytes, SHA256 `88f6d386a8332a516cf3c5a196572555294b1f46c4b59c3fdf954f66e811d3bc`.
- Compilación release x64 de demostración: correcta, APK 126,5 MB. `tools/run_android.ps1`: instalación Success y lanzamiento Status ok. El script fuerza el cierre de la instancia anterior antes de abrir la aplicación instalada.
- Pixel_10a, con Wi-Fi y datos móviles apagados (ambos valores 0): selección manual mediante los botones y toques en el mapa. Origen 19.13076, -72.39464 (Haití), destino 19.00110, -69.68510 (RD). Ambos marcadores y coordenadas quedaron guardados y visibles, sin el salto de zoom anterior. [Captura de los puntos](isla-puntos.png).
- Se pulsó Calcular ruta con esos puntos: mensaje explícito de cobertura del grafo, sin borrar los marcadores ni dibujar rutas ficticias. [Captura del mensaje](isla-cobertura-rutas.png).
- Ver origen y destino encuadra ambos puntos; Ver toda la isla devuelve la vista general. Se revisó la máscara visual que oculta Cuba y las Islas Turcas y Caicos en los bordes. No se encontraron excepciones fatales de la aplicación en logcat durante la prueba.
- Se restauraron Wi-Fi y datos móviles al estado original y se dejó abierta la aplicación normal con la isla y ambos puntos.

Se mantienen pendientes la revisión cartográfica y las pruebas de rendimiento físico. Esta ampliación de selección no amplía la búsqueda por nombres ni el grafo de rutas.
