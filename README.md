# Ruta RD Offline

Proyecto escolar Android desarrollado con Flutter. Incluye cartografía local
de República Dominicana, búsqueda sin conexión y rutas a pie, en bicicleta,
coche y moto. Versión actual: **1.5.1-demo+11**.

La aplicación está en [`ruta_rd`](ruta_rd). El catálogo y los grafos están
incluidos en los assets; no necesita un servidor de mapas al ejecutarse.

- Dos entradas independientes para buscar origen y destino.
- Selección sobre el mapa únicamente tras activar el botón de cada entrada.
- Cálculo automático, distancia en m/km y tiempo orientativo por transporte.
- Favoritos guardados, modo oscuro y seguimiento GPS en primer plano.
- Interfaz sin panel inferior; mapa, locales y nombres de calles disponibles
  según los datos cartográficos incluidos.

## Continuar el desarrollo

Consultar primero [`CONTINUAR.md`](ruta_rd/CONTINUAR.md), las
[instrucciones del proyecto](ruta_rd/AGENTS.md) y el
[plan de trabajo](PLAN_DE_TRABAJO.md). El código está separado de los datos,
la búsqueda, los controladores de pantalla y el motor de rutas.

Desde `ruta_rd`, con Flutter y Android SDK instalados:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Para generar el APK universal e instalarlo en el emulador configurado:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_phone.ps1
```

Ese script requiere el árbol Git limpio y prepara APK, fuentes y manifiestos
en `ruta_rd/entregables`, una carpeta excluida del repositorio.

## Pruebas y datos

La [evidencia de la actualización](ruta_rd/docs/evidence/dos-campos-busqueda.md)
registra los resultados y el alcance del emulador. Las pruebas físicas de
versiones anteriores no sustituyen una validación de esta versión en teléfono.

Los datos de negocios y vías proceden de OSM y otras fuentes documentadas; el
catálogo no contiene todos los negocios existentes. Los tiempos no incorporan
tráfico en tiempo real. Consultar [navegación](ruta_rd/docs/delivery/NAVEGACION.md)
y [datos y licencias](ruta_rd/docs/delivery/DATOS-Y-LICENCIAS.md).
