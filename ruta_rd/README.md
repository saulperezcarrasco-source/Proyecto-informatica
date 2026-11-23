# Ruta RD Offline

Aplicación Android para consultar República Dominicana y calcular rutas sin conexión a pie, en bici, coche o moto. El alcance y los contratos están en `docs/architecture.md` y `docs/contracts.md`; el plan inicial está en `../PLAN_DE_TRABAJO.md`.

**Entrega actual: 1.3.1-demo+7 universal (ARM32, ARM64 y x64).** Búsqueda nacional
offline de 96.873 registros OSM y navegación en primer plano con flecha
GPS, distancia restante, pausa y avisos de salida de ruta. Añade búsqueda por
palabras y ciudad cercana, etiquetas de locales seleccionables y distancias m/km.
El selector cambia perfil de vías y tiempo estimado; no incluye tráfico. Añade
logo propio en icono/inicio, marcadores distintos y cámara/rumbo suavizados. Para continuar
el desarrollo en otro equipo, leer [CONTINUAR.md](CONTINUAR.md). Para instalar
en teléfonos, seguir [TELEFONOS.md](docs/delivery/TELEFONOS.md). La prueba del
teléfono físico para esta actualización queda pendiente por elección del usuario;
esta entrega se verifica en el emulador.

Incluye un mapa vectorial de RD disponible sin internet desde la instalación. Haití y los países vecinos quedan ocultos y fuera de la selección y del grafo de rutas. **Toca el mapa una vez para A y otra para B: la línea azul se calcula automáticamente.** Los botones **Elegir origen en mapa** y **Elegir destino en mapa** permiten reemplazarlos y recalcular. Los marcadores aparecen al soltar el toque sin reiniciar la cartografía. **Trazando ruta…** indica progreso; los errores se muestran sobre el mapa. **Calcular ruta** permite reintentar manualmente y **Ver toda RD** recupera la vista nacional. El icono del encabezado cambia entre claro y oscuro y conserva el tema al cerrar. Las rutas usan caminos peatonales OSM de RD incluidos en el APK; los accesos naranjas son aproximaciones no verificadas. La búsqueda nacional incluye los registros con nombre disponibles en OSM dentro de RD; el piloto conserva sus IDs. Detalle nativo hasta zoom 15 y ampliación visual hasta 19. [Preparación del recorte](tools/dominican_region/README.md), [verificación vigente](docs/evidence/solo-rd.md).

Abrir esta carpeta en Android Studio con los plugins Flutter y Dart. Instalar Android SDK Command-line Tools desde SDK Manager, revisar las licencias con `flutter doctor --android-licenses`, crear e iniciar un emulador Android o conectar un teléfono y ejecutar `lib/main.dart`. Consultar `docs/evidence/fase-0.md` para el estado de las verificaciones.

**Mi ubicación** solicita una posición puntual y muestra la precisión junto al origen. Respeta el permiso aproximado, permite cancelar y conserva el origen manual ante fallos o lecturas fuera de la isla. El GPS no se consulta al abrir la app. Si el servicio está apagado o el permiso está bloqueado, ofrece el ajuste correspondiente; la selección manual sigue disponible. En Android se usa LocationManager para evitar exigir servicios de escaneo Wi-Fi. [Fase 5 y matriz de permisos](docs/evidence/fase-5.md).

Para instalar y abrir la compilación optimizada de demostración en Pixel_10a, desde esta carpeta ejecutar `powershell -ExecutionPolicy Bypass -File tools/run_android.ps1 -Universal`. Si el APK ya fue compilado, añadir `-SkipBuild`. Con -Universal incluye ARM32, ARM64 y x64 y utiliza firma de desarrollo. tools/build_phone.ps1 genera también fuentes y evidencias de distribución desde Git limpio. Ejecutar las pruebas antes de la compilación final, de forma secuencial. La instalación se comprueba antes de abrir la actividad.
