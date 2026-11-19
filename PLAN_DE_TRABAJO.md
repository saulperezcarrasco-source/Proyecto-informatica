# Plan de trabajo para Codex — Ruta RD Offline

- Plataforma: Android.
- Tecnología: Flutter y Dart.
- IDE: Android Studio.
- Desarrollo: 17 de noviembre al 3 de diciembre de 2026.
- Presentación: 4 de diciembre de 2026.

Este documento describe trabajo pendiente. Ninguna fase debe considerarse
completada hasta ejecutar sus pruebas y registrar los resultados.

## 1. Objetivo

Crear una aplicación Android que permita:

1. Consultar el mapa de una zona piloto de República Dominicana.
2. Buscar lugares sin internet.
3. Seleccionar origen y destino.
4. Obtener la ubicación mediante GPS cuando esté disponible.
5. Calcular una ruta peatonal sin conexión.
6. Mostrar recorrido, distancia y tiempo estimado.

La aplicación debe funcionar sin internet desde la primera apertura
después de instalar el APK, porque los datos de la zona estarán incluidos
en la aplicación.

### Zona piloto

Se propone un sector pequeño de la Ciudad Colonial de Santo Domingo.

Los límites exactos se definirán en la fase 0. No comenzar con todo el
país: primero validar una región pequeña y controlable.

### Definición de “mejor ruta”

Para el MVP, significa la ruta de menor distancia dentro del grafo
peatonal disponible.

No significa la ruta más segura, accesible o rápida según condiciones
reales.

### Fuera del MVP

- Rutas para vehículos.
- Tráfico en tiempo real.
- Navegación por voz.
- Ubicación en segundo plano.
- Cobertura nacional.
- Descarga de nuevas regiones.
- Cuentas y autenticación.
- Backend.
- Publicación en Google Play.

Flutter Web será una ampliación posterior. Ejecutar en Chrome no valida
el comportamiento offline, los permisos ni la instalación de Android.

### Uso del prototipo anterior

El prototipo web anterior puede utilizarse como referencia visual.

Sus calles y conexiones simuladas no deben presentarse como cartografía
real. Durante el desarrollo se permiten fixtures identificados; la
aceptación cartográfica del MVP requiere datos reales revisados.

Si no se dispone de esos datos, entregar explícitamente una demostración
simulada y dejar pendiente el requisito correspondiente.

---

## 2. Arquitectura

Usar una arquitectura pequeña y fácil de entender.

| Componente | Tecnología | Responsabilidad |
|---|---|---|
| Interfaz | Flutter Material 3 | Pantallas, controles y mensajes |
| Estado | ChangeNotifier y ListenableBuilder | Estado de la pantalla principal |
| Mapa | flutter_map y latlong2 | Capas, líneas y marcadores locales |
| Ubicación | geolocator | GPS puntual y permisos |
| Datos | JSON y GeoJSON en assets | Región incluida en el APK |
| Búsqueda | Servicio Dart puro | Buscar y ordenar lugares |
| Rutas | Servicio Dart puro con Dijkstra | Menor distancia |
| Pruebas | flutter_test e integration_test | Lógica, widgets y flujo Android |

### Decisiones obligatorias

1. Usar Flutter estable.
2. Seleccionar paquetes compatibles con la versión instalada.
3. Registrar versiones y conservar `pubspec.lock`.
4. No actualizar herramientas a mitad del MVP sin una causa concreta.
5. No introducir backend ni APIs remotas.
6. No utilizar mapas, fuentes o recursos que necesiten internet.
7. No incorporar un administrador de estado adicional en el MVP.
8. Mantener el cálculo de rutas separado de Flutter.

### Mapa offline

Para la zona pequeña:

- Dibujar calles con `PolylineLayer`.
- Dibujar áreas con `PolygonLayer`.
- Dibujar lugares con marcadores.
- Cargar geometrías desde archivos locales.
- No añadir un `TileLayer` remoto.

El resultado será un mapa vectorial sencillo. Para ampliar la cobertura
habrá que revisar formatos, almacenamiento y rendimiento.

### Android offline

No utilizar service workers para Android.

La aplicación funciona sin internet porque sus datos y recursos están
incluidos en `assets`. No debe necesitar una descarga inicial de mapas.

---

## 3. Estructura del proyecto

```text
ruta_rd/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   └── models/
│   ├── data/
│   │   └── region_repository.dart
│   ├── features/
│   │   ├── home/
│   │   ├── map/
│   │   ├── search/
│   │   ├── routing/
│   │   └── location/
│   └── shared/
│       └── widgets/
├── assets/
│   └── regions/
│       └── zona_piloto/
│           ├── manifest.json
│           ├── map.geojson
│           ├── places.json
│           └── graph.json
├── test/
│   ├── fixtures/
│   ├── unit/
│   └── widgets/
├── integration_test/
├── tools/
│   └── prepare_region/
├── docs/
│   ├── architecture.md
│   ├── contracts.md
│   ├── data-source.md
│   ├── progress.md
│   └── evidence/
├── AGENTS.md
├── PLAN_CODEX_FLUTTER.md
└── README.md
```

### Responsabilidades

- `core/models`: contratos compartidos.
- `data`: carga y validación de archivos.
- `home`: pantalla principal y controlador.
- `map`: representación visual de geometrías.
- `search`: búsqueda local.
- `routing`: distancias, conexión al grafo y Dijkstra.
- `location`: interfaz del servicio y adaptador de GPS.
- `shared/widgets`: mensajes y controles reutilizables.
- `tools/prepare_region`: generación reproducible de datos.

No crear capas genéricas ni repositorios abstractos adicionales sin una
necesidad concreta.

---

## 4. Contratos de datos

Definir estos contratos antes de implementar las funcionalidades.

### Coordinate

- `lat`: double.
- `lon`: double.

### RegionManifest

- `id`.
- `name`.
- `version`.
- `bounds`.
- `source`.
- `attribution`.
- `generatedAt`.
- `isDemo`.

### Place

- `id`.
- `name`.
- `category`.
- `coordinate`.
- `aliases`, opcional.

### GraphNode

- `id`.
- `coordinate`.

### GraphEdge

- `from`.
- `to`.
- `distanceMeters`.

Cada arista es dirigida. Un tramo transitable en ambos sentidos requiere
dos aristas.

### RoutingGraph

- `nodes`.
- `edges`.

### RouteResult

- Coordenadas del recorrido.
- Distancia recorrida sobre el grafo.
- Tiempo estimado.
- Distancia de aproximación del origen.
- Distancia de aproximación del destino.

Las aproximaciones deben informarse separadas de la distancia del grafo.

### RouteFailure

Distinguir al menos:

- `invalidPoint`.
- `outsideCoverage`.
- `tooFarFromGraph`.
- `disconnected`.
- `invalidData`.

### Servicios

Definir firmas equivalentes a:

```text
loadRegion()
searchPlaces(query)
calculateRoute(origin, destination)
getCurrentLocation()
```

El motor de rutas no debe importar Flutter ni geolocator.

### Convenciones

- Distancias: metros.
- Tiempo: minutos.
- Coordenadas internas: campos nombrados `lat` y `lon`.
- GeoJSON: `[longitud, latitud]`.
- Adaptadores explícitos entre modelos y librerías.

### Estados de pantalla

Carga de región:

- `loading`.
- `ready`.
- `error`.

Ubicación:

- `idle`.
- `locating`.
- `success`.
- `failure`.

Ruta:

- `idle`.
- `calculating`.
- `success`.
- `failure`.

Cambiar origen o destino elimina la ruta anterior.

---

## 5. Método de trabajo con Codex

### Antes de aprobar el MVP

Las fases 0 a 6 se ejecutan secuencialmente.

- Trabajar en una sola línea de desarrollo.
- Mantener commits pequeños.
- No abrir ramas paralelas de funcionalidades.
- No iniciar otra fase con un criterio bloqueante pendiente.

Si el repositorio exige pull requests, usar una sola rama temporal por
fase y fusionarla antes de comenzar la siguiente.

### Después de aprobar el MVP

Abrir ramas independientes para mejoras.

Cada sesión de Codex tendrá:

- Una funcionalidad.
- Una rama.
- Un worktree.
- Archivos asignados.
- Pruebas definidas.
- Criterios de aceptación.

### Contenido recomendado de AGENTS.md

```text
Lee PLAN_CODEX_FLUTTER.md, docs/architecture.md y docs/contracts.md.

Implementa únicamente la fase o funcionalidad asignada.

Revisa Git antes de editar.
Conserva cambios ajenos.
No uses reset --hard.

Respeta los contratos compartidos.
Justifica dependencias nuevas.
No añadas backend ni servicios remotos.

No presentes datos simulados como reales.
No presentes una función incompleta como implementada.

Separa lógica de interfaz.
Gestiona datos inválidos, permisos denegados y rutas inexistentes.

Ejecuta formato, análisis y pruebas pertinentes.
No declares probado un APK o dispositivo que no ejecutaste.

Si faltan SDK o dispositivo, registra el bloqueo.
Actualiza docs/progress.md y docs/evidence/fase-N.md.

Al finalizar entrega:
- Cambios realizados.
- Archivos principales.
- Comandos ejecutados.
- Resultados.
- Pasos de prueba manual.
- Pendientes y limitaciones.

No comiences la siguiente fase automáticamente.
No abras ramas paralelas antes de aceptar el MVP.
```

### Comprobaciones comunes

Desde la raíz del proyecto:

```bash
flutter analyze
flutter test
flutter devices
flutter run -d <ID_ANDROID>
```

Formatear las carpetas que ya existan:

```bash
dart format lib test integration_test
```

Sustituir `<ID_ANDROID>` por el identificador real.

Cuando exista la prueba de integración:

```bash
flutter test integration_test/app_test.dart -d <ID_ANDROID>
```

### Android Studio

1. Abrir la carpeta que contiene `pubspec.yaml`.
2. Seleccionar un dispositivo Android.
3. Ejecutar `lib/main.dart`.
4. Revisar errores en Run y Logcat.
5. Para simular ubicación:
   Emulator → Extended controls → Location.

La validación definitiva de GPS y del APK se realizará en teléfono físico.

### Evidencia de cada fase

Guardar en `docs/evidence/fase-N.md`:

- Fecha.
- Commit.
- Versión de Flutter.
- Dispositivo.
- Versión de Android.
- Comandos ejecutados.
- Resultado esperado.
- Resultado observado.
- Capturas útiles.
- Problemas y pruebas pendientes.

Una prueba no ejecutada se marca PENDIENTE, nunca PASS.

---

## 6. Calendario

| Fase | Fecha | Resultado verificable |
|---|---|---|
| 0. Entorno y contratos | 17 nov. | Aplicación básica en Android |
| 1. Interfaz | 18–19 nov. | Pantalla móvil navegable |
| 2. Datos y mapa local | 20–23 nov. | Mapa visible sin red |
| 3. Búsqueda y selección | 24 nov. | Lugares y puntos seleccionables |
| 4. Rutas | 25–26 nov. | Recorrido calculado localmente |
| 5. GPS | 27 nov. | Ubicación opcional integrada |
| 6. Aceptación MVP | 28 nov. | APK offline validado |
| 7. Ramas de mejoras | 29 nov.–1 dic. | Funcionalidades independientes |
| 8. Integración y entrega | 2–3 dic. | APK y presentación preparados |
| Presentación | 4 dic. | Demostración en modo avión |

Son días naturales.

Si el MVP se retrasa, reducir las mejoras de la fase 7. No omitir pruebas
offline para mantener las fechas.

---

## Fase 0 — Entorno, proyecto y alcance

### Objetivo

Ejecutar una aplicación Flutter básica en Android y definir los contratos.

### Instrucciones para Codex

1. Inspeccionar la carpeta antes de crear archivos.
2. Si ya existe un proyecto Flutter, conservarlo.
3. Si solo existe el prototipo web, crear un proyecto separado.
4. Ejecutar:

```bash
flutter --version
flutter doctor -v
flutter devices
```

5. Registrar diagnósticos.
6. Configurar Flutter y Dart en Android Studio.
7. Instalar Android SDK y crear un emulador.
8. Utilizar el JDK compatible recomendado por las herramientas.
9. Si corresponde, ejecutar:

```bash
flutter doctor --android-licenses
```

El responsable debe revisar los términos que acepte.

10. Crear el proyecto si todavía no existe:

```bash
flutter create --platforms=android ruta_rd
```

11. Sustituir el contador por una pantalla “Ruta RD Offline”.
12. Definir límites de la zona piloto y modo peatonal.
13. Crear los modelos y documentos de contratos.
14. Configurar Git sin reinicializar repositorios existentes.
15. Crear el primer commit.

### Cómo probar

1. Ejecutar `flutter doctor -v`.
2. Resolver errores que bloqueen Android.
3. Iniciar el emulador.
4. Ejecutar la aplicación.
5. Comprobar su nombre en pantalla.
6. Cambiar un texto y probar hot reload.
7. Ejecutar análisis y pruebas.
8. Sustituir la prueba del contador por una prueba de la pantalla inicial.

### Criterios de aceptación

- [ ] La aplicación abre en Android.
- [ ] No hay errores que bloqueen el desarrollo Android.
- [ ] La zona piloto está definida.
- [ ] Los contratos están documentados.
- [ ] Existe un commit inicial.
- [ ] Hay evidencia de las comprobaciones.

Si falta SDK o dispositivo, registrar la validación pendiente.

---

## Fase 1 — Interfaz del MVP

### Objetivo

Crear una pantalla utilizable antes de integrar datos y rutas.

### Instrucciones para Codex

1. Crear `HomeScreen` y `HomeController`.
2. Usar `ChangeNotifier`.
3. Diseñar el área principal del mapa.
4. Añadir buscador.
5. Añadir panel de origen y destino.
6. Añadir botones:
   - Mi ubicación.
   - Calcular ruta.
   - Limpiar.
7. Deshabilitar funciones aún no implementadas.
8. Crear estados de carga y error.
9. Añadir acción Reintentar.
10. Crear componentes para resultados y resumen de ruta.
11. Usar español.
12. Usar SafeArea y controles de al menos 48 píxeles lógicos.
13. Adaptar el diseño al teclado y al texto grande.
14. Identificar cualquier simulación visual.

### Cómo probar

1. Ejecutar en emulador de pantalla pequeña.
2. Comprobar que no aparecen franjas de overflow.
3. Abrir y cerrar el teclado.
4. Verificar que los controles siguen accesibles.
5. Rotar el dispositivo.
6. Aumentar el tamaño del texto en Android.
7. Mostrar carga y error mediante fixtures de prueba.
8. Comprobar botones deshabilitados y Reintentar.
9. Ejecutar pruebas de widgets de los estados principales.

### Criterios de aceptación

- [ ] La interfaz no se desborda.
- [ ] El teclado no impide completar las acciones.
- [ ] Los estados son comprensibles.
- [ ] Los botones pendientes están deshabilitados.
- [ ] No se muestran éxitos ficticios.
- [ ] Las pruebas de widgets pasan.

---

## Fase 2 — Datos y mapa offline

### Objetivo

Mostrar cartografía local de la zona sin servicios externos.

### Instrucciones para Codex

1. Obtener un extracto de OpenStreetMap durante el desarrollo.
2. Registrar fuente, fecha, atribución y licencia.
3. Crear un script reproducible en `tools/prepare_region`.
4. Para una región pequeña puede utilizarse Python y OSM XML.
5. Generar:

```text
manifest.json
map.geojson
places.json
graph.json
```

6. Incluir todos los nodos referenciados.
7. Recortar de forma consistente la cobertura.
8. No crear conexiones artificiales por los límites de la región.
9. Conectar nodos consecutivos de vías caminables.
10. Conectar calles únicamente cuando compartan nodos OSM.
11. No conectar líneas solo porque se crucen visualmente.
12. Documentar reglas de:
    - access.
    - foot.
    - Restricciones peatonales.
    - Barreras.
    - Escaleras.
13. Excluir accesos prohibidos y revisar casos ambiguos.
14. Calcular distancias geográficas positivas.
15. Generar aristas en ambos sentidos cuando corresponda.
16. Validar:
    - IDs únicos.
    - Referencias existentes.
    - Coordenadas.
    - Pesos.
    - Tamaño de archivos.
    - Componentes desconectados.
17. No unir componentes inventando conexiones.
18. Declarar archivos en `pubspec.yaml`.
19. Cargar mediante `rootBundle`.
20. Integrar capas locales con `flutter_map`.
21. Mostrar cobertura, atribución e indicador de datos demo/reales.
22. Gestionar JSON inválido y archivos ausentes.

### Cómo probar

1. Instalar una compilación con los assets.
2. Activar modo avión.
3. Apagar también Wi-Fi.
4. Abrir la aplicación.
5. Comprobar mapa, desplazamiento y zoom.
6. Con conexión durante la revisión, comparar cinco lugares y cinco
   conexiones con la fuente.
7. Probar archivos válidos e inválidos.
8. Probar referencias inexistentes y coordenadas incorrectas.
9. Revisar el informe de componentes desconectados.

### Criterios de aceptación

- [ ] El mapa aparece sin red.
- [ ] No existen solicitudes a servicios cartográficos.
- [ ] Los datos pueden regenerarse.
- [ ] Las referencias del grafo son válidas.
- [ ] La atribución está visible.
- [ ] Los errores de datos no cierran la aplicación.
- [ ] La cartografía real fue revisada.

Una cuadrícula sintética permite desarrollar una demo, pero no aprobar
el requisito de cartografía real.

---

## Fase 3 — Búsqueda y selección

### Objetivo

Elegir origen y destino sin depender del GPS.

### Instrucciones para Codex

1. Implementar `SearchService` como Dart puro.
2. Buscar únicamente en datos cargados localmente.
3. Normalizar:
   - Mayúsculas.
   - Espacios.
   - Diacríticos del español.
4. Buscar por nombre y alias.
5. Ordenar:
   - Coincidencia exacta.
   - Prefijo.
   - Coincidencia parcial.
6. Resolver empates de forma estable.
7. Mostrar un máximo de diez resultados.
8. Una consulta vacía limpia la lista.
9. Mostrar mensaje si no existen coincidencias.
10. Permitir fijar un resultado como origen o destino.
11. Añadir modos explícitos para elegir puntos tocando el mapa.
12. El gesto normal no debe sustituir puntos accidentalmente.
13. Rechazar puntos fuera de cobertura.
14. Mantener una selección válida si el nuevo punto es inválido.
15. Mostrar marcadores A y B.
16. Mostrar nombres o coordenadas.
17. Añadir Limpiar.
18. Cambiar puntos elimina el recorrido anterior.

### Cómo probar

1. Buscar un lugar con y sin tilde.
2. Repetir con mayúsculas y espacios adicionales.
3. Buscar un nombre inexistente.
4. Vaciar el campo.
5. Elegir un resultado como destino.
6. Verificar marcador y centrado.
7. Elegir origen y destino tocando el mapa.
8. Tocar fuera de cobertura.
9. Repetir todo sin conexión.
10. Ejecutar pruebas de normalización, alias, orden y límite.

### Criterios de aceptación

- [ ] La búsqueda funciona offline.
- [ ] El orden es estable.
- [ ] Los estados vacíos son correctos.
- [ ] Ambos puntos pueden seleccionarse manualmente.
- [ ] Se rechazan puntos fuera de cobertura.
- [ ] No se necesita permiso GPS.

---

## Fase 4 — Rutas peatonales

### Objetivo

Calcular y representar la menor distancia sobre el grafo.

### Instrucciones para Codex

1. Construir la lista de adyacencia una vez.
2. Implementar Dijkstra.
3. Reconstruir el recorrido mediante predecesores.
4. Respetar dirección y pesos.
5. Rechazar datos inválidos.
6. Devolver errores tipados a la interfaz.
7. Ajustar cada punto al nodo cercano.
8. Usar inicialmente un máximo configurable de 100 metros.
9. Rechazar puntos demasiado alejados.
10. No inventar conexiones.
11. Gestionar grafo desconectado.
12. Si origen y destino son iguales, devolver cero metros.
13. Si puntos diferentes se ajustan al mismo nodo, informar la aproximación.
14. Dibujar el recorrido usando las conexiones del grafo.
15. Dibujar aproximaciones con línea discontinua.
16. Identificar esas aproximaciones como accesos no verificados.
17. Separar distancia del recorrido y aproximaciones.
18. Estimar tiempo a 4,5 km/h.
19. Mostrar que el tiempo es aproximado.
20. Ajustar el encuadre del mapa.
21. Evitar cálculos duplicados.
22. Permitir borrar la ruta.
23. Medir rendimiento antes de añadir complejidad.

Para el grafo pequeño se permite Dijkstra con selección lineal O(V²).
Si bloquea la interfaz, trasladar el cálculo a un isolate.

### Cómo probar

1. Crear un grafo de prueba:
   - A→B: 4.
   - B→C: 5.
   - A→C: 20.
2. El resultado A→C debe ser A-B-C, distancia 9.
3. Probar dirección inversa sin aristas.
4. Probar nodo desconectado.
5. Probar origen igual a destino.
6. Probar pesos inválidos.
7. Probar punto a más de 100 metros del grafo.
8. Revisar tres rutas reales dentro de la región.
9. Cambiar destino y comprobar que desaparece la ruta anterior.
10. Limpiar.
11. Repetir sin red.
12. Medir duración en el teléfono de referencia.

Meta inicial: menos de un segundo para el grafo piloto.

### Criterios de aceptación

- [ ] El algoritmo obtiene la menor distancia esperada.
- [ ] Respeta dirección.
- [ ] Gestiona ausencia de ruta.
- [ ] No sustituye una ruta por una línea recta.
- [ ] Las aproximaciones están identificadas.
- [ ] La interfaz se recupera después de un error.
- [ ] El funcionamiento offline está comprobado.

---

## Fase 5 — GPS y permisos

### Objetivo

Añadir ubicación sin convertirla en requisito para usar la app.

### Instrucciones para Codex

1. Definir `LocationService`.
2. Implementar adaptador `geolocator`.
3. Permitir un servicio falso en pruebas.
4. Configurar permisos Android según la versión instalada del paquete.
5. Solicitar ubicación solo al pulsar Mi ubicación.
6. No solicitar ubicación en segundo plano.
7. Gestionar:
   - Servicio desactivado.
   - Permiso denegado.
   - Denegación permanente.
   - Tiempo agotado.
   - Error de ubicación.
8. Usar una consulta puntual.
9. Configurar tiempo máximo, por ejemplo 15 segundos.
10. Mostrar posición y precisión.
11. Si está fuera de cobertura, mantener selección manual.
12. No sustituir un origen válido por una posición inválida.
13. Ofrecer abrir ajustes cuando corresponda.
14. Evitar solicitudes repetitivas.
15. No actualizar widgets o controladores destruidos.

### Cómo probar

1. En emulador, simular posición dentro de cobertura.
2. Aceptar permiso y comprobar el punto.
3. Simular posición fuera de cobertura.
4. Restablecer permisos.
5. Probar denegación.
6. Probar denegación permanente cuando Android lo permita.
7. Desactivar ubicación.
8. Probar ubicación aproximada.
9. Comprobar selección manual en todos los casos.
10. Probar en teléfono físico sin datos móviles ni Wi-Fi.
11. Salir de pantalla mientras se obtiene la ubicación.

El GPS puede tardar o fallar sin conexión. Debe existir una salida
manual clara.

### Criterios de aceptación

- [ ] La ubicación disponible se representa correctamente.
- [ ] Se muestra precisión.
- [ ] La denegación no bloquea el flujo.
- [ ] No hay bucles de permisos.
- [ ] Se gestiona el tiempo agotado.
- [ ] Existe evidencia en Android físico.

---

## Fase 6 — Aceptación del MVP

### Objetivo

Validar una versión completa antes de abrir ramas paralelas.

### Instrucciones para Codex

1. Añadir integración del flujo:
   cargar → buscar → elegir → calcular → limpiar.
2. Ejecutar análisis y pruebas.
3. Revisar dependencias accidentales de red.
4. Generar APK de QA:

```bash
flutter build apk --debug
```

5. Identificarlo como APK de pruebas.
6. Instalarlo en el teléfono de referencia.
7. Probar primera apertura offline.
8. Para ello, usar instalación limpia o borrar datos después de instalar.
9. Desactivar red antes de abrir por primera vez.
10. Registrar tiempos y tamaño.
11. Corregir problemas bloqueantes.
12. Registrar límites de datos.
13. Crear etiqueta `mvp-v0.1.0` únicamente después de aprobar.

Para medir rendimiento final, utilizar profile/release en el dispositivo
objetivo, no basarse solo en tiempos debug.

### Prueba de aceptación

- [ ] Primera apertura sin red muestra el mapa.
- [ ] La búsqueda funciona.
- [ ] Se puede operar con GPS rechazado.
- [ ] Diez pares de puntos producen ruta o error esperado.
- [ ] Los recorridos siguen conexiones válidas.
- [ ] Fuera de cobertura muestra un error recuperable.
- [ ] Grafo desconectado muestra un error recuperable.
- [ ] GPS tiene evidencia física o limitación pendiente explícita.
- [ ] Forzar detención y reabrir no elimina disponibilidad de datos.
- [ ] No hay datos simulados presentados como reales.
- [ ] Las pruebas automáticas pasan.
- [ ] El APK probado corresponde al commit registrado.

### Punto de control

Solo con el MVP aceptado se habilita la fase 7.

Si falta cartografía o dispositivo, utilizar el tiempo previsto para
mejoras para resolver ese bloqueo.

---

## Fase 7 — Ramas de funcionalidades

### Condición de entrada

Debe existir:

- MVP aceptado.
- Evidencia de pruebas.
- Etiqueta `mvp-v0.1.0`.
- `main` estable.

### Preparación

Comprobar el estado de Git.

Si existe remoto, sincronizar `main` con `pull --ff-only`. Si no existe,
omitir ese paso.

```bash
git switch main
git status
```

Crear un worktree por sesión:

```bash
git worktree add ../ruta-rd-favorites -b feat/favorites main
git worktree add ../ruta-rd-filters -b feat/place-filters main
git worktree add ../ruta-rd-accessibility -b feat/accessibility main
```

Estos comandos asumen ramas y carpetas nuevas. Si existen, inspeccionar
y reutilizar; no borrar trabajo previo.

### Reglas de coordinación

1. Una sesión modifica únicamente su worktree.
2. Cada rama tiene carpetas asignadas.
3. Un integrador modifica el cableado compartido.
4. Los contratos se cambian mediante un cambio separado.
5. Un responsable modifica `pubspec.yaml` y `pubspec.lock` por vez.
6. No resolver archivos de bloqueo copiando versiones arbitrarias.
7. Coordinar pruebas en dispositivos: instalaciones con el mismo
   applicationId pueden reemplazarse entre sí.

Si favoritos requiere `shared_preferences`, añadir y validar esa
dependencia en un cambio secuencial antes de bifurcar, o mediante un PR
previo independiente.

### Rama A — Favoritos

Rama: `feat/favorites`.

Archivos principales:

```text
lib/features/favorites/
test/unit/favorites/
test/widgets/favorites/
```

#### Instrucciones

1. Marcar y desmarcar lugares.
2. Guardar por ID.
3. Persistir localmente.
4. Guardar referencia de región y versión.
5. Mostrar lista de favoritos.
6. Gestionar lugares eliminados tras actualizar datos.
7. Exponer repositorio y panel integrables.
8. No duplicar todo el estado del mapa.

#### Cómo probar

1. Guardar dos lugares.
2. Cerrar y abrir la aplicación.
3. Comprobar persistencia.
4. Eliminar uno.
5. Repetir sin conexión.
6. Probar almacenamiento vacío e inválido con un repositorio falso.

#### Aceptación

- [ ] Persistencia correcta.
- [ ] Sin dependencias de red.
- [ ] No modifica el motor de rutas.
- [ ] Errores de almacenamiento recuperables.

### Rama B — Filtros

Rama: `feat/place-filters`.

Archivos principales:

```text
lib/features/place_filters/
test/unit/place_filters/
test/widgets/place_filters/
```

#### Instrucciones

1. Obtener categorías de los datos.
2. Añadir opción Todos.
3. Combinar categoría y consulta textual.
4. Filtrar resultados y marcadores de lugares.
5. Conservar origen, destino y ruta aunque queden fuera del filtro.
6. Exponer función pura y selector integrable.
7. No cambiar el contrato Place.

#### Cómo probar

1. Seleccionar categoría.
2. Combinar con búsqueda.
3. Probar combinación sin coincidencias.
4. Limpiar filtro.
5. Comprobar lista y marcadores.
6. Confirmar que los puntos elegidos no cambian.
7. Repetir sin red.

#### Aceptación

- [ ] Resultados consistentes.
- [ ] Filtro y búsqueda se combinan.
- [ ] No se altera la ruta por filtrar.
- [ ] Estados vacíos correctos.

### Rama C — Accesibilidad

Rama: `feat/accessibility`.

Archivos principales:

```text
lib/shared/widgets/
lib/app.dart
```

Coordinar cualquier archivo compartido con el integrador.

#### Instrucciones

1. Añadir etiquetas semánticas.
2. Revisar orden de foco.
3. Mejorar contraste.
4. Soportar texto grande.
5. No depender únicamente del color.
6. Mantener controles táctiles utilizables.
7. Proporcionar selección textual de lugares como alternativa al mapa.
8. No cambiar lógica de rutas.

#### Cómo probar

1. Activar TalkBack.
2. Identificar buscador y botones.
3. Seleccionar origen y destino por texto.
4. Aumentar fuente al 200 %.
5. Abrir teclado.
6. Probar pantalla pequeña.
7. Calcular y limpiar una ruta.

#### Aceptación

- [ ] Los controles tienen nombres comprensibles.
- [ ] Texto grande no oculta funciones esenciales.
- [ ] Existe alternativa textual al mapa.
- [ ] El flujo principal sigue funcionando.

### Encargo para cada agente

```text
Implementa exclusivamente [funcionalidad].

Rama: [rama].
Worktree: [carpeta].
Archivos permitidos: [carpetas].

Confirma que el MVP fue aceptado y existe mvp-v0.1.0.
Lee los contratos.

Implementa requisitos, errores y pruebas de la sección correspondiente.
No modifiques contratos ni dependencias compartidas silenciosamente.

Ejecuta formato, análisis y pruebas.
Entrega un commit revisable y pasos de prueba manual.

No fusiones otras ramas.
No modifiques otro worktree.
```

### Cierre de fase

Cada mejora seleccionada debe estar revisada y probada.

No es obligatorio completar las tres antes de la presentación. Priorizar
estabilidad y fecha.

---

## Fase 8 — Integración y entrega

### Objetivo

Entregar un APK probado y una demostración reproducible.

### Instrucciones para Codex

1. Integrar una rama a la vez.
2. Usar PR si hay remoto o merge local revisado.
3. Registrar commits.
4. Ejecutar verificaciones después de cada integración.
5. Resolver conflictos entendiendo ambos cambios.
6. Conectar módulos a la pantalla principal.
7. Probar interacciones entre mejoras.
8. Ejecutar regresión completa.
9. Congelar funciones el 2 de diciembre.
10. El 3 de diciembre corregir únicamente problemas críticos.
11. Preparar configuración de firma.
12. Generar APK:

```bash
flutter build apk --release
```

13. Si se utiliza firma de desarrollo, identificarlo como APK de
    demostración; no afirmar que está listo para Google Play.
14. Para firma propia, conservar keystore y contraseñas fuera del
    repositorio.
15. No publicar `key.properties` ni credenciales.
16. Registrar versión, commit y dispositivo.
17. Copiar APK a una carpeta de entregables.
18. Preparar instrucciones de instalación.
19. Documentar datos, licencia y limitaciones.
20. Preparar presentación de cinco minutos.
21. Grabar video de respaldo.
22. Etiquetar `v1.0.0-demo` después de probar el APK final.

### Cómo probar

1. Instalar exactamente el APK que se entregará.
2. No sustituir esta prueba por una ejecución debug desde Android Studio.
3. Activar modo avión y apagar Wi-Fi antes de la primera apertura.
4. Abrir mapa.
5. Buscar lugar.
6. Seleccionar origen y destino.
7. Calcular ruta.
8. Probar GPS y alternativa manual.
9. Probar las mejoras integradas.
10. Verificar que documentos y APK corresponden a la misma versión.

### Guion de presentación

1. Problema que resuelve.
2. Zona disponible.
3. Activación de modo avión.
4. Búsqueda de un lugar.
5. Selección de puntos.
6. Cálculo de ruta.
7. Limitaciones.
8. Próxima etapa.

### Criterios de aceptación

- [ ] APK final instalable.
- [ ] Primer arranque offline probado.
- [ ] Flujo principal completo.
- [ ] Mejoras integradas probadas.
- [ ] Código reproducible.
- [ ] Licencias y origen de datos documentados.
- [ ] Presentación preparada.
- [ ] Video de respaldo disponible.

Compilar correctamente no demuestra que la aplicación se instaló o
funcionó en un dispositivo.

---

## 7. Ampliaciones posteriores

Crear ramas desde `main` actualizado.

### Paquetes regionales

Rama: `feat/region-packages`.

Investigar:

- Formato de paquetes.
- Descarga explícita.
- Validación de integridad.
- Espacio disponible.
- Reemplazo atómico.
- Recuperación ante descargas interrumpidas.

### Rendimiento

Rama: `feat/routing-performance`.

- Medir grafos mayores.
- Revisar estructuras y algoritmo.
- Conservar resultados equivalentes con pruebas.
- Evitar cargar todo el país en un JSON gigante.

### Flutter Web

Rama: `feat/flutter-web`.

- Verificar compatibilidad.
- Gestionar permisos en HTTPS.
- Definir almacenamiento y estrategia offline web.
- No asumir que Flutter genera automáticamente una PWA offline completa.
- Mantener pruebas específicas para navegador.

### Vehículos

Rama: `feat/vehicle-routing`.

- Incorporar datos y reglas para vehículos.
- Respetar sentidos.
- Gestionar restricciones de giro.
- Evaluar un motor apropiado.

No convertir rutas peatonales en rutas de vehículos cambiando únicamente
la velocidad estimada.

---

## 8. Registro de avance

Mantener esta tabla en `docs/progress.md`.

| Fase | Estado | Commit | Evidencia | Pendientes |
|---|---|---|---|---|
| 0 | Pendiente | — | fase-0.md | — |
| 1 | Pendiente | — | fase-1.md | — |
| 2 | Pendiente | — | fase-2.md | — |
| 3 | Pendiente | — | fase-3.md | — |
| 4 | Pendiente | — | fase-4.md | — |
| 5 | Pendiente | — | fase-5.md | — |
| 6 | Pendiente | — | fase-6.md | — |
| 7 | Pendiente | — | fase-7.md | — |
| 8 | Pendiente | — | fase-8.md | — |

Estados permitidos:

- Pendiente.
- En curso.
- Bloqueada.
- Aceptada.

No marcar Aceptada si quedan criterios bloqueantes sin comprobar.

---

## 9. Primer encargo para pegar en Codex

```text
Usa PLAN_CODEX_FLUTTER.md como especificación de Ruta RD Offline.

Desarrollaremos con Flutter/Dart y probaremos Android desde Android Studio.

Implementa únicamente la fase 0.

Inspecciona la carpeta antes de crear archivos.
Conserva cambios existentes.
Si existe un prototipo web, no lo sobrescribas.

No reutilices conexiones simuladas como cartografía real.

Documenta:
- Alcance.
- Zona piloto.
- Contratos.
- Versiones.
- Requisitos pendientes.

Al finalizar entrega:
1. Lo implementado.
2. Archivos principales.
3. Comandos ejecutados y resultados.
4. Pasos exactos para probar en Android Studio.
5. Criterios pendientes de aceptación.

No comiences la fase 1.
No abras ramas paralelas de funcionalidades todavía.
```