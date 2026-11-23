# Repetir la aceptación de fase 6

Alcance solicitado el 20/11/2026: repetir toda la fase 6 en Pixel_10a, sin
requerir un teléfono Android. Arrancar el AVD en frío y esperar a que termine
de iniciar. El emulador no demuestra GPS o rendimiento de un teléfono. La ejecución
borra los datos privados de **Ruta RD Offline** para probar la primera apertura;
no usar una instalación con información que deba conservarse.

Desde la raíz de `ruta_rd`, con Flutter y Android SDK configurados:

```powershell
flutter analyze
flutter test
flutter test integration_test/mvp_acceptance_test.dart integration_test/island_routing_test.dart integration_test/theme_national_test.dart integration_test/search_selection_test.dart integration_test/routing_test.dart -d emulator-5554
powershell -ExecutionPolicy Bypass -File tools/verify_gps_emulator.ps1
# Guardar código y pruebas en un commit antes de construir el APK.
adb devices -l
powershell -ExecutionPolicy Bypass -File tools/verify_phase6.ps1
# Repetir en modo optimizado, también borrando los datos de la app:
powershell -ExecutionPolicy Bypass -File tools/verify_phase6.ps1 -BuildMode release
powershell -ExecutionPolicy Bypass -File tools/run_android.ps1
```

El script genera un APK **PRUEBAS**, guarda commit, SHA256, tamaño, modelo,
arranques de actividad, conectividad y capturas en `build/qa/<commit>/<dispositivo>-<modo>/<fecha-UTC>/`.
Cada ejecución conserva su propio registro. Se rechazan dispositivos ausentes y
una conectividad que no confirme explícitamente ausencia de red predeterminada.
Después de borrar datos se detiene la app. El arranque usa `-S -f 0x10008000`
para quitar tareas previas antes de crear una nueva; evita la actividad residual
observada al actualizar y limpiar una instalación. Se guardan las salidas de
arranque y se comprueba el PID, además de la revisión visual de las capturas.
Compila en modo debug para la arquitectura del dispositivo conectado; ARM en
un teléfono puede requerir descargar componentes del SDK la primera vez.
Compara también el hash del APK instalado. Instala el APK normal de depuración
por defecto, o el modo indicado mediante `-BuildMode`,
sin el ejecutor de integración, limpia datos, desactiva Wi-Fi/datos antes de
abrir, fuerza detención y reabre. Restaura las conexiones que estaban activas.
Si el teléfono tiene otra conexión (Ethernet, tethering, etc.), desconectarla.
Revisar `connectivity.txt`: no debe existir una red predeterminada activa.

Revisar visualmente ambas capturas: cartografía visible, sin pantalla vacía ni
error de carga. Los tiempos `TotalTime` de Android miden la actividad; la espera
de la captura no mide el momento exacto en que el mapa quedó listo. Conservar
el registro y el APK juntos; el archivo de QA no se incluye en Git.

La integración MVP verifica búsqueda real local, origen/destino, línea azul,
limpieza, rechazo de puntos externos y recuperación de un componente OSM
desconectado. Su rechazo GPS usa un adaptador de prueba explícito. Por separado,
`verify_gps_emulator.ps1` ejecuta el adaptador Android real con permiso bloqueado,
ubicación desactivada y lectura de una posición inyectada con `adb emu geo fix`.
Comprueba también rutas manuales después de cada caso y restaura permisos y
configuración de ubicación. Esa posición es simulada; no demuestra recepción
satelital. El script rechaza identificadores de teléfonos físicos.

Las medidas release del emulador se registran como tales. Para rendimiento
físico futuro repetir con APK profile/release en el teléfono objetivo y
registrar primera carga, recálculo, memoria y tamaño. El release actual emplea
firma de desarrollo; no es un artefacto firmado para publicación.

Los diez pares del motor se documentan en `evidence/fase-6.md`. Seguir aristas
OSM válidas no demuestra que cada paso exista o sea transitable en terreno:
revisar barreras, cruces, acceso peatonal y conectividad del piloto antes de
aceptar cartografía. La búsqueda por nombres sigue limitada a Ciudad Colonial;
los puntos manuales y las rutas usan la cobertura nacional disponible de RD.

Al terminar las pruebas en el emulador, restaurar la aplicación normal con
`tools/run_android.ps1`. Registrar aceptación solamente con los pendientes
resueltos; después se podrá crear `mvp-v0.1.0`. No habilitar fase 7 antes.
