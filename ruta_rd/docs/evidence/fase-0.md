# Evidencia de fase 0

Fecha: 19 de noviembre de 2026. Commit inicial del proyecto: 713f990. Emulador: Pixel_10a, Android 17.

- `flutter doctor -v`: Flutter 3.50.0 estable, Dart 3.14.0, Android SDK 36.0.0. Se instalaron las Android SDK Command-line Tools; siete licencias adicionales requieren revisión. Visual Studio no está instalado, pero no es necesario para Android.
- `flutter create --platforms=android ruta_rd`: proyecto creado correctamente.
- `dart format lib test` y `flutter pub get`: completados.
- `flutter analyze`: sin problemas tras sustituir la importación obsoleta por `material_ui` 1.11.1, recomendada por Flutter 3.50.0.
- `flutter test`: una prueba de widgets aprobada.
- `flutter run -d emulator-5554`: APK debug compilado e instalado; pantalla comprobada en el emulador Pixel_10a con Android 17.
- Hot reload: PASS. Se cambió temporalmente el texto, se ejecutó `r` y se comprobó el resultado en [la captura](hot-reload.png); después se restauró el texto original y se recargó de nuevo.
- Ejecución desde la interfaz de Android Studio: PENDIENTE; la aplicación se ejecutó desde la terminal.
- La zona piloto y los contratos iniciales se documentan en `docs/architecture.md` y `docs/contracts.md`; la cartografía real se revisará en fase 2.

No se ha aceptado la fase 0. Las licencias deben ser revisadas y aceptadas por el responsable.
