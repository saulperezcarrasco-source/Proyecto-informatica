# Evidencia de fase 1

Fecha: 19 de noviembre de 2026. Flutter 3.50.0; emulador Pixel_10a, Android 17. Commit: consultar historial.

- `dart format lib test`: completado.
- `flutter analyze`: sin problemas.
- `flutter test`: tres pruebas aprobadas: controles pendientes, carga/error y reintento, pantalla pequeña con texto grande.
- `flutter run -d emulator-5554`: compilación e instalación debug correctas; interfaz revisada en [captura](fase-1.png).
- Posteriormente se reorganizó la interfaz con referencia a Waze: búsqueda superior y mayor espacio para el mapa. El análisis y las tres pruebas volvieron a pasar; la captura anterior corresponde al diseño previo y falta revisar el diseño actualizado en Android.
- La búsqueda está deshabilitada hasta la fase 3; no se puede abrir el teclado mediante ese campo. GPS, ruta y limpieza también están deshabilitados. El mapa es un marcador visual sin cartografía.
- PENDIENTE: comprobación manual de rotación, pantalla pequeña y texto grande en Android; comprobación del teclado cuando exista un campo habilitado. No se ha aceptado la fase 1.
