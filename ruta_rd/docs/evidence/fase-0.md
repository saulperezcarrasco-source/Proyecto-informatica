# Evidencia de fase 0

Fecha: 19 de noviembre de 2026. Commit: pendiente. Dispositivo y versión Android: pendientes.

- `flutter doctor -v`: Flutter 3.50.0 estable, Dart 3.14.0, Android SDK 36.0.0. Se instalaron las Android SDK Command-line Tools; siete licencias adicionales requieren revisión. Visual Studio no está instalado, pero no es necesario para Android.
- `flutter create --platforms=android ruta_rd`: proyecto creado correctamente.
- `dart format lib test` y `flutter pub get`: completados.
- `flutter analyze`: sin problemas tras sustituir la importación obsoleta por `material_ui` 1.11.1, recomendada por Flutter 3.50.0.
- `flutter test`: una prueba de widgets aprobada.
- El emulador Pixel_10a se inició y ADB detectó Android 17; la ejecución de la aplicación está pendiente de finalizar la compilación.
- Ejecución en Android, hot reload y comprobación en Android Studio: PENDIENTE.
- La zona piloto y los contratos iniciales se documentan en `docs/architecture.md` y `docs/contracts.md`; la cartografía real se revisará en fase 2.

No se ha aceptado la fase 0. Las licencias deben ser revisadas y aceptadas por el responsable.
