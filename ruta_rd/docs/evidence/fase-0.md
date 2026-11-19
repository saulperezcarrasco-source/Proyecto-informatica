# Evidencia de fase 0

Fecha: 19 de noviembre de 2026. Commit inicial del proyecto: 713f990. Emulador: Pixel_10a, Android 17.

- `flutter doctor -v`: Flutter 3.50.0 estable, Dart 3.14.0, Android SDK 36.0.0. Las herramientas Android están instaladas y todas las licencias aparecen aceptadas. Visual Studio no está instalado, pero no es necesario para Android.
- `flutter create --platforms=android ruta_rd`: proyecto creado correctamente.
- `dart format lib test` y `flutter pub get`: completados.
- `flutter analyze`: sin problemas tras sustituir la importación obsoleta por `material_ui` 1.11.1, recomendada por Flutter 3.50.0.
- `flutter test`: una prueba de widgets aprobada.
- `flutter run -d emulator-5554`: APK debug compilado e instalado; pantalla comprobada en el emulador Pixel_10a con Android 17.
- Hot reload: PASS. Se cambió temporalmente el texto, se ejecutó `r` y se comprobó el resultado en [la captura](hot-reload.png); después se restauró el texto original y se recargó de nuevo.
- Android Studio: los plugins Flutter y Dart están instalados y se abrió el proyecto. Ejecución desde la interfaz del IDE: PENDIENTE; la aplicación se ejecutó desde la terminal.
- La zona piloto y los contratos iniciales se documentan en `docs/architecture.md` y `docs/contracts.md`; la cartografía real se revisará en fase 2.

La fase 0 se acepta con los criterios cumplidos: aplicación ejecutada en Android, entorno Android disponible, zona y contratos documentados, commit inicial y evidencia. Queda pendiente la comprobación opcional de ejecución desde la interfaz de Android Studio; no sustituye la ejecución ya realizada desde la terminal.
