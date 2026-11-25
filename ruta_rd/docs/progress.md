# Avance

1.5.1-demo+11: navegación con proveedor Android GPS/GNSS explícito, sin consulta
puntual previa ni timeout de 15 s para comenzar el seguimiento. Se libera el
proveedor al cancelar incluso sin primer fix; se recupera al volver al primer
plano y se conserva la pausa manual. Permiso preciso y ubicación desactivada
tienen accesos a sus ajustes. 68 pruebas locales y análisis limpios.
Evidencia de validación Android: [GPS satelital sin red](evidence/gps-satelital-offline.md).

1.5.0-demo+10: pantalla de planificación sin desplazamiento global. El mapa usa
el espacio restante, los resultados se desplazan dentro de un panel acotado y
la distribución se adapta al teclado, texto grande y orientación horizontal.
Análisis limpio y 64 pruebas locales aprobadas. Validación de dispositivos en
[interfaz fija](evidence/interfaz-fija.md).

24/11/2026: revisión de continuidad sin cambios de código: emulador arrancado
en frío, APK 1.4.1-demo+9 reinstalado y prueba nativa de dos campos, rutas,
selección explícita del mapa y tema repetida con resultado PASS. Aplicación
normal dejada abierta. Registro en la evidencia de dos campos de búsqueda.

1.4.1-demo+9: dos campos independientes «Elegir origen» / «Elegir destino», con
«Buscar un lugar» como ejemplo. Se retiran la búsqueda única y las instrucciones
encima del mapa. Cada resultado se asigna al campo activo; se conservan los
iconos para elegir A/B sobre el mapa. Editar o borrar un punto invalida su ruta
sin eliminar el otro y cancela un GPS pendiente si se está editando el origen.
Los toques en mapa/locales solo colocan puntos tras activar su botón A/B.
Evidencia: [dos campos de búsqueda](evidence/dos-campos-busqueda.md).

1.4.0-demo+8: reorganización visual solicitada: desaparecen el panel «Tu
recorrido» y todo el contenido debajo del mapa. Búsqueda, transporte, tarjetas
de origen/destino y acción principal quedan arriba. Favoritos se abre con la
estrella del encabezado; los detalles y la limpieza de ruta siguen disponibles
en un diálogo. Los créditos cartográficos quedan encima del mapa, fuera del
lienzo. Evidencia: [interfaz sin menú inferior](evidence/interfaz-sin-menu-inferior.md).

1.3.1-demo+7: retirado el recuadro de atribución dentro del mapa, sin añadir
iconos ni controles a la cartografía. Los créditos quedan adyacentes al mapa
y en la información cartográfica, tanto en planificación como en navegación.

Ampliación 1.3.0-demo+6: identidad del PNG del usuario en icono/inicio, puntos
con símbolos distintos, instrucciones solicitadas, cuatro perfiles de transporte
y estimaciones, catálogo de 96.873 registros y cámara/rumbo/ETA suavizados.
Las pruebas AOT de cuatro transportes y navegación del emulador finalizaron
correctamente. Evidencia y límites en [movilidad y logo](evidence/movilidad-logo.md).
La revisión final de entrega queda registrada allí; no se afirma GPS físico.
Entrega 1.3 definitiva: análisis limpio, 63 pruebas locales, cuatro pruebas de
políticas y dos fixtures Android AOT aprobados. APK universal reinstalado y
comprobado por interfaz nativa en los cuatro transportes; GNSS offline del
emulador 189 → 106 → 0 m. Logo/instrucciones/iconos, más locales y tema verificados.

Actualización 1.2.0-demo+5: búsqueda por palabras/contexto de ciudad en todo el
catálogo nacional, etiquetas seleccionables de locales, navegación con índice
de segmentos y controles de calidad/continuidad GPS, unidades m/km y retiro
del mensaje solicitado. 57 pruebas locales y el fixture Android AOT de lugares,
navegación y zoom/pan aprobados; detalles en
[precisión y lugares](evidence/precision-navegacion.md). La entrega final se
verifica en emulador por elección del usuario; no se afirma prueba física 1.2.
El APK universal definitivo se instaló y abrió; el GNSS Android sin conexión
actualizó 189 → 105 → 0 m. La ruta Monumento–Puerto Plata mostró 57.5 km y la
navegación 57.6 km con accesos. Búsqueda de negocios/turismo, etiquetas en modo
oscuro y opciones al tocar locales verificadas en esa versión instalada.

Ampliación solicitada tras probar en teléfono: `1.1.0-demo+4` añade navegación
peatonal en primer plano, flecha/avance GPS, búsqueda nacional OSM de 95.118
registros y optimización del mapa. Análisis limpio, 50 pruebas locales y pruebas
Android de navegación, catálogo, rutas, selección, favoritos y tema aprobadas.
En REVVL 7/Android 16, la prueba AOT de 120 movimientos registró 1,92 ms de
trabajo UI medio y percentil 90 de 5,14 ms, con 0 de 301 muestras >16,7 ms.
Las posiciones de esa prueba son inyectadas a nivel de servicio, no GPS físico.
El APK release final está instalado y probado en teléfono y emulador, con
hashes coincidentes. El stream GNSS Android del emulador actualizó 190 → 107 → 0 m
sin conexión; el teléfono calculó Santiago–Puerto Plata desde búsqueda nacional.
La caminata con GPS físico continúa pendiente. El detalle se documenta en
[navegación y búsqueda nacional](evidence/navegacion-nacional.md).

| Fase | Estado | Commit | Evidencia | Pendientes |
|---|---|---|---|---|
| 0 | Aceptada | 713f990 | [fase-0](evidence/fase-0.md) | Comprobar ejecución desde la interfaz de Android Studio |
| 1 | Aceptada | 0ba58a0 y posteriores | [fase-1](evidence/fase-1.md) | Búsqueda real y pruebas funcionales en fase 3 |
| 2 | Aceptada para el MVP de emulador | Consultar historial | [revisión de fuente](evidence/revision-cartografica.md) | Sin certificación de condiciones en terreno |
| 3 | Aceptada | Consultar historial | [fase-3](evidence/fase-3.md) | Sin pendientes funcionales de búsqueda y selección; fase 2 pendiente |
| 4 | Aceptada en el alcance de emulador | Consultar historial | [fase-6](evidence/fase-6.md) | Rendimiento físico no evaluado |
| 5 | Aceptada en el alcance de emulador | Consultar historial | [fase-6](evidence/fase-6.md) | GPS físico no evaluado; posición de prueba identificada como inyectada |
| 6 | MVP aceptado en el alcance de emulador | 36310c9 (APK QA final) | [fase-6](evidence/fase-6.md) | Comparación cartográfica cerrada; avance solicitado por el usuario |
| 7 | Favoritos revisados e integrados en main | a3307f4; merge 5e67d42 | [fase-7](evidence/fase-7.md) | Filtros y accesibilidad adicionales fuera de esta entrega |
| 8 | Aceptada en alcance emulador/demo | Código 29773b0; etiqueta v1.0.0-demo | [fase-8](evidence/fase-8.md) | Sin bloqueos de entrega; firma de desarrollo y destino x86_64 documentados |

20/11/2026, actualización para teléfonos: tras el reporte de cierre al abrir
en un T-Mobile REVVL 7 con Android 16, se corrige la distribución: la entrega
x64 anterior carecía de los motores Flutter ARM. Se genera `1.0.1-demo+3`
universal ARM32/ARM64/x64, con firma y alineación ZIP/ELF de 16 KB verificadas.
El APK exacto pasa arranque offline, búsqueda, ruta azul y persistencia en el
emulador. La ejecución en el teléfono del usuario sigue pendiente; no se
afirma que el cierre físico esté resuelto sin esa prueba.
[Evidencia y descarga local](evidence/android-universal.md).

19/11/2026: corregido el despliegue y el arranque tras el reporte de pantalla vacía. APK release instalado y comprobado después de reiniciar Pixel_10a; búsqueda, selección y ruta verificadas con Wi-Fi y datos apagados. 21 pruebas aprobadas y análisis limpio. [Evidencia y capturas](evidence/correccion-arranque.md). El mapa nacional y la persistencia del modo oscuro también se comprobaron en esta instalación. Se mantienen los pendientes cartográficos y de dispositivo físico indicados arriba.

Ampliación solicitada el 19/11/2026: selección de origen y destino en toda la isla de Santo Domingo (RD y Haití), separada de la cobertura del motor de rutas. [Cambios y validación](evidence/seleccion-isla.md). No implica aceptación cartográfica ni ampliación del grafo.

Corrección posterior del 19/11/2026: grafo peatonal OSM de RD y Haití para calcular rutas fuera del piloto sin conexión. Selección al soltar el toque, manteniendo el mapa y sus cachés. [Pruebas y entrega](evidence/rutas-isla-sin-refresco.md). La búsqueda por nombres sigue siendo piloto y se mantienen las validaciones cartográficas y físicas pendientes.

Trazado automático del 19/11/2026: al colocar ambos puntos o cambiar uno, se calcula la línea azul sin pulsar un botón adicional. Progreso y errores visibles sobre el mapa. [Verificación](evidence/ruta-automatica.md).

Cobertura vigente del 19/11/2026: solo República Dominicana. Se recortaron mapa y grafo, se excluyó Haití mediante el límite nacional y se simplificó la entrada a dos toques directos para A y B. [Pruebas y entrega](evidence/solo-rd.md). Las evidencias anteriores sobre La Española describen versiones históricas.

Fase 6 iniciada el 19/11/2026: 37 pruebas locales aprobadas, análisis limpio,
flujo completo de búsqueda/ruta/limpieza y recuperación de errores aprobado en
Android, diez pares del grafo comprobados, APK QA identificado por commit y
SHA256, primera apertura con datos borrados y reapertura sin red verificadas
visualmente en emulador. Aplicación normal release reinstalada y línea azul
automática comprobada. [Evidencia y límites](evidence/fase-6.md). Continúan
pendientes teléfono físico, GPS real y revisión cartográfica; MVP sin aceptar,
sin etiqueta y sin habilitar fase 7.

20/11/2026: por solicitud del usuario se repitió la fase 6 completa en el
emulador, sin exigir un teléfono Android. 37 pruebas locales y 8 comprobaciones
Android aprobadas; QA debug y release con datos borrados, primera apertura y
reapertura sin red verificadas. Corregidos el paquete ausente en la preparación
GPS y el arranque con tareas Android anteriores tras reinstalar/borrar datos.
Aplicación normal reinstalada, conservada tras reiniciar Android y dejada en
modo oscuro con ruta azul automática. [Resultados actuales](evidence/fase-6.md).
La validación física no se presenta como realizada y no bloquea esta entrega
en emulador. Se conserva la revisión cartográfica pendiente y no se inicia fase 7.

Cierre posterior del 20/11/2026: ante la instrucción de avanzar si la fase 6 está
completada, se terminó la comparación de cinco lugares y cinco conexiones con
la API OSM actual y la trazabilidad completa del grafo piloto. Sin discrepancias.
Se registra la aceptación del MVP para el alcance de emulador solicitado por el
usuario, conservando las limitaciones documentadas. Se etiqueta esta base como
`mvp-v0.1.0` y se inicia fase 7 por favoritos, en una rama aislada. Main queda
como base estable; no se afirma validación de hardware ni de caminos en terreno.
