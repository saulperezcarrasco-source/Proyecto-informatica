# Instrucciones del proyecto

Lee `../PLAN_DE_TRABAJO.md`, `docs/architecture.md` y `docs/contracts.md`. Implementa solo la fase asignada y conserva cambios existentes. No uses reset --hard ni abras ramas paralelas antes de aceptar el MVP. No añadas backend o servicios remotos ni presentes datos simulados como reales. Separa lógica e interfaz, gestiona errores y justifica dependencias nuevas. Ejecuta formato, análisis y pruebas pertinentes; registra resultados y pendientes en `docs/progress.md` y `docs/evidence/fase-N.md`. No declares probado un dispositivo que no ejecutaste ni comiences la siguiente fase automáticamente.

Por solicitud del usuario, instalar y ejecutar cada conjunto de cambios terminado en el emulador Android y verificar el resultado antes de entregarlo. Si una prueba de integración reemplaza el APK, volver a instalar la aplicación normal al finalizar. Registrar cualquier bloqueo de instalación o ejecución.

Para entregar al emulador usar `tools/run_android.ps1` después de las pruebas. No ejecutar comandos Flutter de pruebas/pub en paralelo con la compilación final: regeneran los archivos nativos de plugins. Arrancar Pixel_10a mediante arranque en frío; no combinar carga de una instantánea antigua con `-no-snapshot-save`. Verificar la instalación tras reiniciar el emulador si se modifica el despliegue.
