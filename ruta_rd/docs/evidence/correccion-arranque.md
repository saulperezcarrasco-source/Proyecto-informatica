# Corrección de instalación y pantalla vacía

19 de noviembre de 2026. Reporte del usuario: la aplicación está vacía.

Diagnóstico observado: inicialmente no había emuladores conectados. Al iniciar Pixel_10a, `am start` devolvió `Error type 3: Activity class does not exist` y el gestor de paquetes no mostraba com.example.ruta_rd. La configuración estaba en arranque rápido y las ejecuciones previas usaban no-snapshot-save. La validación previa no había comprobado la conservación de la instalación después de reiniciar por completo el AVD.

Correcciones:

- Se cambió Pixel_10a a arranque en frío y se añadió `tools/run_android.ps1`, que compila un APK de demostración x64, comprueba el arranque de Android, instala, verifica el paquete y abre la actividad.
- La entrega final usa un APK release optimizado con firma de desarrollo, destinado al emulador x64. No es un APK firmado para distribución pública.
- Pantalla de arranque identificable; la carga de datos muestra nombre, progreso y explicación. La carga inicial tiene un máximo de 20 segundos y ofrece Reintentar si falla.
- El paquete nacional se copia primero a un archivo temporal y se renombra al terminar. Un fallo al abrirlo permite Reparar mapa nacional; la zona piloto sigue disponible.
- Se evita recomprimir PMTiles en los recursos Android.

Comprobaciones realizadas:

- `flutter analyze`: sin problemas. `flutter test`: 21 pruebas aprobadas, incluida carga pendiente, tiempo máximo y reintento ante datos inválidos.
- `flutter build apk --release --target-platform android-x64`: correcto. APK de 75,3 MB.
- `tools/run_android.ps1 -SkipBuild`: instalación Success; paquete verificado; lanzamiento Status ok. Android reportó TotalTime 4030 ms en el primer arranque de esta instalación.
- Pantalla completa y mapa local revisados ([captura](arranque-corregido.png)); no se encontraron FATAL EXCEPTION, E/flutter o Unhandled Exception en los registros del proceso de la aplicación durante esa comprobación.

- Reinicio completo de Pixel_10a: el paquete seguía instalado antes de reinstalar; lanzamiento en frío Status ok, TotalTime 2819 ms. Se revisó visualmente la aplicación con contenido.
- Wi-Fi y datos móviles desactivados (ambos valores 0): búsqueda `cafe`, elección de Café Conde de Peñalba y Café La Moricette, cálculo correcto de 166 m / 3 min sobre calles, con aproximaciones de 20 m y 24 m. [Búsqueda](busqueda-corregida.png), [recorrido](ruta-corregida.png). Sin excepciones fatales en logcat durante esta prueba. Se restauraron ambas conexiones al finalizar.
- Cierre forzado y nuevo lanzamiento en frío: Status ok, TotalTime 2342 ms; el modo oscuro se conservó. Botón Ver toda RD comprobado visualmente: [mapa nacional](mapa-nacional-corregido.png). La aplicación quedó abierta en esta vista.

El mapa visual cubre el país; la búsqueda y el grafo para calcular recorridos siguen limitados a Ciudad Colonial. La revisión cartográfica y las pruebas en dispositivo físico siguen pendientes. Los tiempos anteriores son los reportados por Android para iniciar la actividad, no una medición de carga completa de todos los mosaicos.
