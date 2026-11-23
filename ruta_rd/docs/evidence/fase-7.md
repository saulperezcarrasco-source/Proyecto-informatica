# Fase 7 — primera mejora: favoritos

Integración posterior de fase 8: la rama fue revisada e integrada en main por
el merge `5e67d42`. Para la entrega final se utiliza el proyecto original
`ruta_rd`; las referencias al worktree de este registro describen la fase 7.
La evidencia de instalación y paquete final se conserva en fase-8.md.

20/11/2026. Base aceptada en el alcance de emulador: `mvp-v0.1.0`, commit
`02ac56d`. La comparación cartográfica pendiente se cerró antes de iniciar:
[revisión OSM](revision-cartografica.md). Rama aislada `feat/favorites`, worktree
`.worktrees/favorites`. Main conserva el MVP; no se inicia fase 8 ni se fusionan
automáticamente mejoras. El plan permite seleccionar mejoras y no exige las tres.

Se implementa la rama A del plan: marcar/desmarcar lugares, persistir por ID,
región y versión, listar favoritos, elegirlos como origen o destino y gestionar
referencias eliminadas al actualizar los datos. El botón de estrella aparece en
los resultados de búsqueda; la lista se despliega debajo del buscador con una
animación suave. Un lugar ausente se puede eliminar, pero no usar para una ruta.

El almacenamiento usa shared_preferences existente y una clave independiente
del tema. No hay dependencias nuevas ni red. El controlador confirma cambios
solo tras guardarlos; un fallo conserva la lista y permite reintentar. Un JSON
corrupto se mantiene hasta que el usuario confirme restablecer solo favoritos.
No se modifican el motor de rutas ni HomeController.

Como preparación, el commit `32d256e` expone el manifiesto real de la región en
RegionData, documentado en contratos. Se validan ID, versión, procedencia y fecha
al cargar el asset. Place no cambia. Los tests de pantallas existentes reciben
ahora preferencias simuladas, porque su entorno no tiene almacenamiento nativo;
las pruebas Android usan el plugin y almacenamiento reales.

Validación automatizada realizada:

- Análisis sin incidencias y **43 pruebas locales aprobadas**: las 37 anteriores
  y seis nuevas de persistencia, regiones/versiones, errores de escritura, JSON
  inválido, eliminación de referencias ausentes y recuperación confirmada.
- El caso de lugar eliminado se prueba con texto al 200 %.
- Integración Android de favoritos aprobada con Wi-Fi/datos apagados: guardar
  dos lugares, recrear controladores y pantalla, recuperar ambos del almacén,
  elegir A/B y obtener 166,188 m; quitar uno conserva la ruta y sus puntos.
- Las regresiones MVP y de ruta nacional también pasaron: tres pruebas Android
  aprobadas en total. La ruta Dajabón–Santiago mantuvo 130.283,870 m y 2.342
  vértices, con primer cálculo debug de 2.005,028 ms en esta ejecución.

Entrega final realizada desde este worktree con `tools/run_android.ps1`, después
de las pruebas y sin comandos Flutter de pruebas/pub en paralelo. Código de
favoritos: `a3307f4302afa9e8a7ea35fa62dc84316ec00d9c`. El APK normal release x64
se instaló con Success y abrió con Status ok, COLD y TotalTime 2796 ms de
actividad. Se forzó otra detención y reapertura sin red: Status ok, COLD,
TotalTime 1274 ms. La [captura después de reabrir](fase7-persistencia.png)
mostró Favoritos (1); al desplegar la [lista guardada](fase7-lista.png) apareció
Café La Moricette y sus acciones A/B, sin pantalla vacía ni banner debug.

El [registro del APK](fase7-apk.json) conserva tamaño, ruta, commit y SHA256:
102.886.363 bytes, hash
`41bd067bc8ce0e957865de25c6f591416d47705733d16dae333a1a25ba0e4635`,
igual al paquete instalado. En la verificación Android confirmó Active default
network: none; no se encontraron E/flutter, FATAL EXCEPTION o Unhandled Exception
en el logcat del proceso. Al finalizar se restauraron Wi-Fi y datos a 1 y se
dejó abierta la aplicación normal, en modo oscuro, con la lista visible.
Los tiempos corresponden al emulador, no al hardware físico.

[Salida de pruebas y mediciones](fase7-resultados.txt). La mejora seleccionada
de favoritos queda implementada y validada para revisión. Main no se fusionó
con la rama; para ejecutar esta versión desde el código debe utilizarse el
proyecto `.worktrees/favorites/ruta_rd`, cuyo APK ya está en el emulador.
La búsqueda de lugares sigue limitada
al piloto de Ciudad Colonial; las rutas y el mapa mantienen la cobertura RD.
Filtros y mejoras adicionales de accesibilidad no forman parte de esta primera
mejora seleccionada. Las limitaciones físicas y cartográficas del MVP continúan
documentadas; no se afirma prueba en teléfono físico.
