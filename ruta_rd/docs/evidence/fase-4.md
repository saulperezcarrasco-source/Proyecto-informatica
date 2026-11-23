# Fase 4: rutas peatonales

Fecha: 19 de noviembre de 2026. Flutter 3.50.0, Dart 3.14.0. Emulador Pixel_10a Android 17. Compilación debug. Commit: consultar historial de este documento.

Implementado:

- Dijkstra y adyacencia construida una vez, reconstrucción por predecesores y aristas dirigidas. Motor Dart sin importaciones Flutter o GPS.
- Validación de nodos, referencias, pesos positivos finitos y máximo de aproximación configurable (100 m por defecto). Coordenadas inválidas y fuera de cobertura producen fallos tipados.
- Distancia sobre el grafo separada de ambas aproximaciones, tiempo a 75 m/min (4,5 km/h) y accesos naranjas discontinuos identificados como no verificados.
- Origen igual al destino devuelve cero sin aproximaciones. Dos puntos diferentes en el mismo nodo muestran cero sobre calles y sus aproximaciones separadas.
- Encuadre de la ruta y los accesos, también para recorridos de un solo nodo. No hay línea recta de sustitución ante un error.
- Cálculo duplicado bloqueado. Cambiar puntos o limpiar cancela resultados obsoletos. Borrar ruta conserva origen y destino; Limpiar elimina todo. La interfaz permite corregir puntos y calcular después de una desconexión.

Comprobaciones:

- `dart format lib test integration_test`: completado.
- `flutter analyze`: sin problemas.
- `flutter test`: 17 pruebas aprobadas. Incluyen A→B=4, B→C=5 y A→C=20, reconstrucción A-B-C con distancia 9; sentido inverso sin aristas; nodo desconectado; pesos inválidos; nodos duplicados; coordenadas inválidas; umbral de aproximación; mismo nodo; origen igual; recuperación y cancelación.
- `flutter test integration_test/routing_test.dart -d emulator-5554`: PASS con Wi-Fi y datos del emulador desactivados. Se probaron los botones Calcular ruta, Borrar ruta y Limpiar, cambio de destino, desconexión real del grafo y recuperación.
- Se comprobó cada segmento de tres recorridos contra una arista dirigida existente y que su suma coincide con la distancia indicada. Son recorridos sobre el extracto OSM incluido; no constituyen una inspección de transitabilidad en campo.

| Origen | Destino | Distancia sobre grafo | Cálculo debug en emulador |
|---|---|---|---|
| Café Conde de Peñalba | Café La Moricette | 166,188 m | 8,456 ms |
| Café La Moricette | Cafeteria Sabor Real | 440,517 m | 1,799 ms |
| Cafeteria Sabor Real | Café Conde de Peñalba | 597,657 m | 2,443 ms |

También se verificaron Café La Moricette y Café Santo Domingo: distintos puntos ajustados al mismo nodo, con aproximaciones positivas y distancia de grafo cero explicada en pantalla.

Entrega al emulador: se reinstaló la app normal después del APK de integración y se verificó visualmente la ruta de 166 m, con accesos separados y botón Borrar ruta ([captura](fase4.png)). Se restauraron Wi-Fi y datos al estado anterior. Las pruebas de rutas no solicitaron GPS.

Pendientes externos: rendimiento en teléfono físico de referencia, medición profile/release para aceptación final y revisión cartográfica detallada de fase 2. No se afirma que se ejecutó un teléfono físico. Todas las funciones de fase 4 están implementadas; se conserva el estado En curso hasta completar esas validaciones.

Ampliación posterior: se permite guardar origen y destino en toda la isla, conservando el alcance piloto del grafo. Los errores por falta de datos explican esa diferencia y conservan ambos puntos. Véase [selección de toda la isla](seleccion-isla.md).

Corrección siguiente: se añadió el grafo real de toda la isla para rutas fuera del piloto y se eliminó la reconstrucción del mapa al seleccionar. La limitación de rutas del párrafo anterior corresponde a la entrega previa. Evidencia vigente: [rutas de la isla y puntos inmediatos](rutas-isla-sin-refresco.md).

Trazado automático: al colocar ambos puntos o cambiar cualquiera de ellos se calcula y dibuja la ruta sin pulsar un botón. [Prueba del flujo automático](ruta-automatica.md).
