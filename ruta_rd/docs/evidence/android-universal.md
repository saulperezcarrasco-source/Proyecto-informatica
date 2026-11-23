# Corrección de distribución Android para teléfonos

20/11/2026. El usuario informó cierre inmediato en un T-Mobile REVVL 7 con
Android 16 y solicitó compatibilidad con teléfonos de distintos modelos.
Solo se encontró conectado emulator-5554; no se obtuvo el logcat del teléfono.
No se presenta como confirmado el motivo exacto de su cierre.

Se inspeccionó la entrega anterior `v1.0.0-demo-android-x64`: contiene
libapp.so y libflutter.so únicamente en lib/x86_64. En ARM hay bibliotecas
auxiliares JNI, pero no el motor ni el programa Flutter. Por tanto ese APK
no es una distribución válida para teléfonos ARM. La nueva verificación
rechazó correctamente ese archivo por `Falta motor completo:
armeabi-v7a/libapp.so`.

Se compiló `1.0.1-demo+3`, código `6c9ae3936baf080b7e9035efda1b54f45f6235f3`,
con `flutter build apk --release --target-platform android-arm,android-arm64,android-x64`.
Los cambios posteriores a ese commit son documentación y evidencia; no cambian
el programa compilado. No se añadieron dependencias ni se modificó lógica Dart.

Archivo: `entregables/v1.0.1-demo/ruta-rd-v1.0.1-demo-android-universal.apk`.
136.867.063 bytes; SHA256
`3ad5e31402d9e9ec6a568bf11b5129ad3eb667d0df868f2105da72cd14eb1924`.
Android mínimo API 24 (7.0), target API 36 (16), versionCode 3. Incluye
armeabi-v7a, arm64-v8a y x86_64 con libapp.so y libflutter.so completos.
Firma Android Debug verificada con apksigner. El paquete e identidad de firma
se conservan para actualizar la demo anterior sin desinstalar ni borrar datos.

Verificaciones nuevas: zipalign `-c -P 16 4` aprobado; inspección independiente
de todos los segmentos ELF PT_LOAD de ocho bibliotecas ARM64/x64, con alineación
de al menos 16 KB, aprobada. Se verificó también la presencia de PMTiles y grafo
RDI. Estas comprobaciones siguen la [documentación Android de páginas de 16 KB](https://developer.android.com/guide/practices/page-sizes).
El verificador no modifica el APK. [Resultado](telefono-verificacion.txt).

El script `tools/build_phone.ps1` exige código guardado, registra el commit y
SHA256, genera la entrega universal y usa `tools/run_android.ps1 -SkipBuild`
para instalar exactamente ese APK, sin sustituirlo por una compilación x64.
La opción `-Universal` de run_android permite también compilar las tres ABI.

Prueba del APK normal release en Pixel_10a, Android 17 API 37 x86_64, páginas
de 16 KB: instalación Success y arranque COLD de 1.119 ms. Tras borrar solo
datos de la app y activar modo avión con Wi-Fi/datos apagados, primer arranque
981 ms, mapa de RD visible, búsqueda cafe, guardado de dos favoritos y selección
A/B con ruta azul automática de 166 m. Tras cambiar a oscuro y forzar cierre,
reapertura 647 ms; ambos favoritos y el tema persistieron. Todos los controles
se accionaron mediante la UI real y se inspeccionaron las capturas.
[Prueba ejecutada](telefono-pruebas.txt), [ruta](telefono-ruta.png),
[persistencia](telefono-persistencia.png). Los tiempos son observaciones del
emulador; no mediciones de teléfonos ni garantía de rendimiento.

Se restauraron Wi-Fi y datos y se desactivó modo avión. No se repitieron las
43 pruebas Dart porque el cambio es de empaquetado y versión; se ejecutó una
verificación de contenido nativo y una prueba real del APK resultante.

Después de reiniciar Android, la aplicación siguió instalada y abrió COLD
en 5.042 ms. El SHA256 del base.apk instalado coincidió con el universal
entregado. Se seleccionaron A/B desde los dos favoritos persistidos y se
volvió a observar la ruta azul en modo oscuro. La consulta logcat del proceso
para flutter:E y AndroidRuntime:E no devolvió errores. Se dejó la aplicación
normal abierta, con modo avión 0. [Captura tras reinicio](telefono-reinicio.png).

La compatibilidad de arquitectura se amplía a Android ARM32/ARM64/x64 desde
API 24. No cubre iPhone, Android anteriores ni asegura funcionamiento en cada
fabricante. No se ejecutó aún en hardware ARM ni en Android 16 físico. La
confirmación del cierre en el teléfono requiere instalar esta versión y, si
persiste, obtener su logcat de crash. El GPS real y las condiciones de campo
siguen sin validación física. [Instalación](../delivery/TELEFONOS.md).
