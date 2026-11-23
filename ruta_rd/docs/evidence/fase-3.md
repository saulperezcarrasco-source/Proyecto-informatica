# Fase 3: búsqueda y selección

Fecha: 19 de noviembre de 2026. Flutter 3.50.0, Dart 3.14.0. Emulador Pixel_10a, Android 17 (emulator-5554). Commit: consultar historial de este documento.

Cambios: búsqueda por nombre y alias, normalización de mayúsculas, espacios y tildes (incluida composición Unicode), coincidencia exacta/prefijo/parcial con desempate por nombre e ID y máximo de diez resultados. Selección por texto o por modo explícito del mapa, cancelación del modo, marcadores A/B y coordenadas. Seleccionar un resultado vacía la búsqueda y centra el punto elegido; cambiar cualquier punto elimina la ruta anterior. Rechazar un punto inválido conserva ambas selecciones válidas. Limpiar elimina todos los puntos, búsqueda y recorrido.

Los alias se extraen de alt_name, short_name, name:es y name:en del extracto OSM cuando están presentes. No se inventan alias de los lugares.

Verificación:

- `flutter analyze`: sin problemas.
- `flutter test`: doce pruebas aprobadas, incluidas orden estable, alias, límite, consultas vacías/sin coincidencias, cobertura, conservación de selección, cambio de enfoque y limpieza.
- `flutter test integration_test/search_selection_test.dart -d emulator-5554`: PASS. Prueba real en Android con Wi-Fi y datos del emulador desactivados mediante `adb shell svc wifi disable` y `adb shell svc data disable`. La red del equipo de desarrollo permaneció disponible para compilar.
- El flujo Android buscó `  CAFE  ` y `café`, eligió origen y destino, comprobó ausencia de coincidencias, borró consulta y puntos, y fijó A/B tocando el mapa. Un servicio GPS de prueba registró cero llamadas. Se verificó también el rechazo fuera de cobertura y conservación del origen; no equivale a validar el GPS físico.
- Se corrigió la prueba para volver a tocar el buscador tras cerrar el teclado y esperar el reconocimiento de toque simple del mapa.
- Se reinstaló y ejecutó la aplicación normal. Se comprobó la búsqueda `cafe` con ambos ajustes de red a 0 ([captura](fase3-offline.png)) y después se restauraron Wi-Fi y datos al estado anterior.

Fase 3 aceptada para búsqueda y selección. La fase 2 conserva pendientes de revisión cartográfica y aceptación offline de instalación limpia; esta prueba no acepta el MVP completo.
