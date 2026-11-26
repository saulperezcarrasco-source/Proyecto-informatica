# Ruta RD Offline 1.6.0-demo — Android universal

Usar `ruta-rd-v1.6.0-demo-android-universal.apk` para telefonos Android.
Incluye ARM de 32 bits, ARM64 y x86_64. El APK anterior marcado android-x64
es solo para emuladores compatibles y no debe usarse en telefonos ARM.
Requiere Android 7.0 o posterior (minSdk 24; targetSdk 36 / Android 16).
No es una aplicacion para iPhone ni una garantia de todos los dispositivos.

1. Copiar el APK universal al telefono y abrirlo desde Archivos/Descargas.
2. Si Android lo solicita, permitir a esa aplicacion instalar este archivo.
3. Actualizar Ruta RD Offline. Conserva el mismo paquete y firma de desarrollo;
   no hace falta desinstalar ni borrar favoritos para actualizar la demo anterior.
4. Abrir la aplicacion y esperar la preparacion local inicial del mapa.
5. Probar en modo avion: mapa, busqueda `cafe`, A/B y ruta azul automatica.
6. Comprobar favoritos y modo oscuro al cerrar y abrir.
7. Para Mi ubicacion, activar ubicacion y conceder permiso. Si no se obtiene
   una posicion, seleccionar A/B manualmente. La busqueda ahora incluye
   95.118 registros con nombre disponibles en OSM dentro de RD.
8. Con una ruta calculada, pulsar Iniciar navegacion. Consultar NAVEGACION.md
   para seguimiento de posicion, flecha, pausa y distancia restante.

Este APK tiene firma de desarrollo, no es una publicacion Google Play.
Incluye verificaciones de firma, las tres arquitecturas completas y alineacion
ZIP/ELF de 16 KB para las bibliotecas de 64 bits. Estas comprobaciones no
sustituyen la prueba en cada telefono. No se afirma validacion fisica sin ella.

Si vuelve a cerrarse, registrar modelo, version Android y mensaje. Si se conecta
por USB con depuracion, se puede obtener el error real sin borrar datos:

```powershell
adb devices
adb -s NUMERO_DEL_TELEFONO logcat -b crash -d
```

Para reconstruir, ejecutar `tools/build_phone.ps1` con Flutter, SDK Android y
JAVA_HOME configurados, despues de guardar el codigo en Git. No ejecutar
Flutter test/pub en paralelo con esa compilacion. El script tambien instala
el mismo APK universal en el emulador para comprobar su arranque.
