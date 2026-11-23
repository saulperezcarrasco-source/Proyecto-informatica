# Continuar el desarrollo de Ruta RD Offline

Antecedente del 20/11/2026: versión `1.0.1-demo+3`, main. Código de ese APK universal:
`6c9ae3936baf080b7e9035efda1b54f45f6235f3`; los commits siguientes añaden
documentación y evidencia. La etiqueta anterior `v1.0.0-demo` identifica la
entrega histórica x64, no la actualización universal para teléfonos.

Versión vigente: `1.4.1-demo+9`. El manifiesto de la entrega identifica el commit
compilado. Añade NavigationController/NavigationScreen para seguimiento GPS en
primer plano y NationalSearch para 95.118 registros de RD en un isolate. Los
datos comprimidos están en assets/search/places.rds: conservar esa extensión,
porque Flutter trata .json.gz como un asset precomprimido y cambia su ruta al
empaquetarlo. Regenerador: tools/dominican_region/places.py con el entorno
osmium/shapely existente. No dibujar todos los registros como widgets del mapa.
El modo de etiquetas por tesela y caché adaptativa sustituye el renderizado de
etiquetas por frame. Consultar docs/delivery/NAVEGACION.md para comportamiento
y límites actuales; los apartados anteriores del MVP son antecedentes.

Ampliación 1.2: PlaceCatalog indexa locales para NationalPlacesLayer (canvas,
máximo 45 etiquetas). NationalSearch combina nombre/alias/contexto de ciudad.
NavigationController indexa segmentos, limita saltos por cruces y descarta
precisión peor de 35 m. Las distancias usan formatDistance, m/km desde 1.000 m.
Evidencia vigente: docs/evidence/precision-navegacion.md. Las mediciones de
REVVL 7 registradas para 1.1 son históricas; esta 1.2 se valida en emulador.

## Abrir el proyecto

GitHub: https://github.com/saulperezcarrasco-source/Proyecto-informatica.
Continuar desde `main`. La actualización publicada conserva el historial remoto
y el árbol completo actual, sin enviar un mapa obsoleto de más de 100 MB que
existía en el historial local. Ese historial se conserva localmente en
`historial-local-v1.4.1`; no hace falta publicar esa rama. Algunos hashes de las
evidencias identifican compilaciones locales anteriores a esta sincronización.

La actualización 1.4.1 usa dos entradas de búsqueda en PlanningEndpoints, una
para cada extremo. HomeScreen mantiene sus textos sincronizados con selecciones
por búsqueda/mapa/GPS/favoritos. HomeController.clearEndpoint invalida el trazado
al editar un extremo, manteniendo el opuesto. Ya no se muestran instrucciones
permanentes sobre el mapa. Validación: docs/evidence/dos-campos-busqueda.md.

La interfaz 1.4 termina en el mapa: no tiene panel ni menú debajo. Los controles
de planificación están arriba, PlanningEndpoints permite elegir A/B, la estrella
abre favoritos y Detalles de ruta muestra las aproximaciones y permite borrar
el trazado. La navegación conserva su pantalla propia. Consultar
docs/evidence/interfaz-sin-menu-inferior.md para la validación de esta entrega.

La ampliación 1.3 añade TravelMode, grafos RDI2 para bici/coche/moto y A* por
arista entrante para giros. Solo un grafo nacional permanece activo. Regenerar
con tools/dominican_region/mobility.py (incluye temporal_filter.py); no se
necesita regenerar para ejecutar porque los assets están incluidos. Los RDI2
deben conservar sus manifiestos y verificación SHA. Las velocidades medias
orientativas son 4,5/15/40/35 km/h; no representan tráfico ni velocidad legal.
El catálogo revisión 3 tiene 96.873 registros y conserva IDs/versiones de
favoritos. Los locales sin nombre registrado se marcan expresamente así.
assets/brand contiene el PNG original y el símbolo para iconos; regenerar las
densidades mediante tools/prepare_brand.ps1 si se sustituye el símbolo.
Evidencia vigente de esta ampliación: docs/evidence/movilidad-logo.md.

Descomprimir el ZIP de fuentes completo, conservando la estructura. Abrir
`ruta_rd` en Android Studio; `PLAN_DE_TRABAJO.md` queda en la carpeta superior.
El ZIP contiene fuentes y datos locales; no incluye Git ni el SDK instalado,
compilaciones temporales, configuración local del equipo o claves de firma.
Se puede inicializar un repositorio nuevo o usar el repositorio original para
conservar el historial. No sobrescribir trabajo existente.

Entorno usado: Flutter 3.50.0 stable, Dart 3.14.0, SDK Android compile/target
36, Build Tools 36.0.0 y NDK 28.2.13676358. Android Studio y sus plugins Flutter
y Dart; configurar JAVA_HOME con el JDK compatible de Android Studio. Usar
`flutter doctor -v` para comprobar el equipo y resolver sus dependencias.

Desde `ruta_rd`, con conexión para descargar las herramientas y dependencias:

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

Las rutas locales absolutas de las evidencias son registros del equipo de
origen, no configuración para el nuevo equipo. Android Studio debe generar
su propio android/local.properties. No cambiar las dependencias fijadas sin
motivo. Los datos PMTiles, grafo y piloto ya están incluidos: no hay que volver
a descargarlos para ejecutar el mapa sin internet.

## Compilar para teléfonos Android

```powershell
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

Resultado: `build/app/outputs/flutter-apk/app-release.apk`. Incluye ARM32,
ARM64 y x64 y requiere Android 7/API 24 o posterior. La firma es de desarrollo;
otro equipo generará su propio certificado y puede no poder actualizar encima
de la app firmada en el equipo original. Para distribución futura, definir una
firma estable con credenciales fuera del repositorio. No incluir contraseñas
ni keystores en un ZIP de fuentes.

`tools/verify_phone_apk.ps1 -Apk RUTA_AL_APK` verifica la firma, las tres ABI,
los datos locales y alineación ZIP/ELF de 16 KB. Requiere SDK Android y JAVA_HOME.
No ejecutar Flutter test/pub en paralelo con la compilación final.

`tools/run_android.ps1 -Universal` compila e instala el universal en el AVD
Pixel_10a/emulator-5554 del equipo original; ajustar ese entorno en otro equipo.
Sin -Universal el script conserva su modo histórico para emulador x64.
`tools/build_phone.ps1` automatiza la entrega universal desde un repositorio
Git limpio y también instala en ese AVD. Para otro dispositivo, usar Flutter
o adb indicando su ID, sin asumir el nombre del emulador original.

## Estado comprobado y trabajo pendiente

Funcionan mapa offline de RD, A/B manuales, ruta azul automática sobre caminos
disponibles, búsqueda piloto, favoritos persistentes, modo oscuro y manejo de
errores GPS. La fase 8 registró 43 pruebas locales y nueve comprobaciones Android.
El universal se probó aparte con datos limpios, sin conexión, búsqueda/ruta,
favoritos/tema al reabrir y arranque tras reiniciar el emulador Android 17.

La navegación, el catálogo y los gestos se probaron además en el REVVL 7 ARM64,
Android 16, en modo profile AOT, con posiciones de prueba a nivel de servicio.
El seguimiento nativo se comprueba por separado con GNSS inyectado en emulador;
no confundirlo con caminar en terreno con GPS físico. El APK x64 histórico
carecía de motores ARM; usar siempre el universal para teléfonos.
El detalle vigente está en docs/evidence/navegacion-nacional.md.

Para repetir la medición, usar el driver test_driver/integration_test.dart y
el target integration_test/navigation_test.dart con `flutter drive --profile`.
El harness usa benchmarkLive y temporizadores reales durante el muestreo: no
medir con pump(Duration), que introduce pausas artificiales. La dependencia
flutter_driver es exclusivamente de desarrollo y viene del SDK Flutter.

Pendientes funcionales: filtros por categoría y revisión adicional de
accesibilidad/TalkBack. La búsqueda ya incluye registros con nombre de toda RD
disponibles en el extracto OSM; no garantiza todos los negocios reales ni
equivalencia con Google Maps. Validar rendimiento y GPS en teléfono físico.
No hay rutas para vehículos ni seguimiento en segundo plano.

Leer `AGENTS.md`, `docs/architecture.md`, `docs/contracts.md`, `docs/progress.md`
y `docs/evidence/android-universal.md` antes de modificar. Los documentos
históricos describen sus versiones; el registro universal es el vigente para
la distribución Android. Mantener origen/licencias de datos y registrar
pruebas reales. Aplicar también cada cambio terminado al emulador y verificarlo.
