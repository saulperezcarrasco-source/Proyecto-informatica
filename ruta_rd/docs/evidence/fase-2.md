# Evidencia de fase 2

Fecha: 19 de noviembre de 2026. Fase en curso.

- Descarga de un extracto real desde la API oficial OSM: correcta.
- Preparación inicial: 439 nodos, 1046 aristas dirigidas, 190 lugares.
- Datos y script reproducible incluidos; biblioteca flutter_map 8.3.2 y latlong2 0.10.1.
- Visualización inicial de tramos con atribución y gestión de error/reintento; no usa capas remotas.
- `flutter analyze`: sin problemas. `flutter test`: siete pruebas de interfaz aprobadas tras integrar los assets. No sustituyen las pruebas específicas de datos y Android offline.
- Se instaló y ejecutó la versión en Android; la revisión detectó ancho cero en el mapa. Se fijó el ancho disponible y se añadió una comprobación de tamaño. Calles visibles en el emulador ([captura](fase2-mapa.png)); análisis y siete pruebas aprobados.
- PENDIENTE: validación completa de datos y componentes, polígonos y marcadores, revisión de cartografía y prueba de primera apertura offline en Android. No se acepta la fase 2 con estos requisitos pendientes.
