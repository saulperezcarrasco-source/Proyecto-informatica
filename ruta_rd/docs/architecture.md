# Arquitectura y alcance

GPS 1.6.1: consulta precisa de origen y navegación comparten el canal satelital.
La consulta puntual posee su propia suscripción cancelable de hasta 60 s; no
detiene otras suscripciones. GnssStatus.Callback solo recoge diagnóstico y nunca
bloquea posiciones si no informa satélites. El panel de diagnóstico se actualiza
cada 2 s mientras está abierto y permite copiar un informe sin coordenadas.

Ampliación 1.3: los cuatro modos de transporte tienen perfiles separados; a pie
conserva el piloto/RDI1 y bici/coche/moto usan RDI2 con accesos, sentidos y giros
OSM. Un único worker nacional activo limita memoria al cambiar modo. El grafo
y A* se mantienen fuera del hilo UI. Las estimaciones usan velocidades medias;
no se añade tráfico ni servicios remotos. Un pase conservador excluye sentidos
condicionales y motorroad sin permiso explícito de bicicleta. Las restricciones
via-way se evitan. tools/dominican_region/mobility.py reproduce ambos pases.
El logo original se guarda en assets/brand; Android tiene iconos adaptativos y
splash, y Flutter muestra el logo grande durante la preparación. La cámara
interpela posiciones durante 450 ms y descarta desplazamientos <2 m. El rumbo
se suaviza circularmente y ETA usa solo desplazamientos recientes fiables.

Actualización 1.1.0-demo: búsqueda nacional OSM en un isolate persistente con
descompresión/indexación y consultas fuera del hilo UI, debounce de 120 ms y
respuestas obsoletas descartadas. El piloto conserva sus IDs y rutas; el catálogo
nacional añade IDs rd:node/way/relation y referencias de favoritos independientes
dominican-search/2026-11-18. La búsqueda nacional se carga después del piloto;
si falla, se mantiene la selección manual y se muestra el estado recuperable.

NavigationController sigue posiciones en primer plano mediante LocationService.watch,
proyecta sobre la geometría de la ruta y actualiza distancia restante, rumbo,
estado GPS y giros geométricos sin ejecutar A* ni reconstruir HomeScreen por fix.
NavigationScreen tiene vista de mapa amplia y controles de seguimiento/pausa/salida.
Detiene suscripciones al salir o entrar al fondo. Origen/destino originales se
conservan; la flecha representa la posición actual. No es navegación de vehículos.
El mapa usa LabelMode.tile y caché raster adaptativa para evitar trabajo de
colisión/etiquetado por frame y expulsión constante durante zoom. El resto de
este documento conserva antecedentes del MVP; estas ampliaciones sustituyen
la limitación histórica de búsqueda a Ciudad Colonial.

Ampliación 1.2.0: el catálogo nacional también alimenta una capa canvas de locales
seleccionables, con índice geográfico y un máximo de 45 etiquetas visibles.
Reutiliza hasta 400 TextPainter y omite los símbolos POI duplicados del basemap;
conserva las etiquetas de calles/ciudades y la máscara nacional. No construye
un widget por cada registro del país. La precisión de navegación añade índice
de segmentos, continuidad temporal, rechazo de señal pobre/saltos y seguimiento
de accesos al grafo. No requiere nuevas dependencias ni servicios remotos.

La máscara territorial de 6.871 vértices se omite únicamente cuando una prueba
conservadora demuestra que la vista completa está dentro de un polígono interior
de RD. Cerca de fronteras y en vista nacional se conserva la máscara original.
El interior tiene 82 vértices y un margen mínimo de 0,012 grados respecto del
límite original; lo genera map_interior.py con validación geométrica de inclusión.
Los filtros de etiquetas a zoom de calle prueban ese interior pequeño primero,
y recurren al límite original si no basta. La selección y el grafo no cambian.

Ruta RD Offline es una aplicación Android peatonal que incluirá los datos de una zona piloto para funcionar desde la primera apertura sin conexión. La ruta será la de menor distancia en el grafo disponible; no representa seguridad ni accesibilidad. No incluye backend ni servicios remotos en ejecución.

Zona piloto inicial: rectángulo geográfico de la Ciudad Colonial de Santo Domingo entre 18.4700 y 18.4780 de latitud norte y -69.8900 y -69.8800 de longitud. Es el límite de trabajo para preparar el extracto; la cobertura transitable y la exactitud de los datos deberán revisarse en la fase 2.

La interfaz Flutter usará ChangeNotifier; la carga local, la búsqueda y el cálculo de rutas estarán separados. El motor de rutas será Dart puro. Las geometrías y el grafo vendrán de assets; el prototipo web es solo referencia visual y sus conexiones no son cartografía real.

Cartografía nacional de República Dominicana con PMTiles local, independiente del grafo piloto. Se incluyen teselas y estilos en assets; se copia el paquete al directorio privado al primer uso y se leen solo intervalos de bytes. No se conecta a un servidor de teselas. flutter_map_vector_tiles dibuja las teselas y estilos locales; las fuentes del sistema reemplazan recursos externos. El tema claro/oscuro se guarda mediante shared_preferences. La cobertura anterior de La Española fue sustituida por el recorte exclusivo de RD.

La selección manual y GPS usa `inDominicanRepublic`: límites de visualización y polígono nacional OSM 307828. Incluye aguas territoriales, sin garantizar tránsito. La búsqueda por nombres sigue usando los lugares locales de Ciudad Colonial. La vista inicial encuadra RD y la máscara del límite nacional oculta Haití y otros países, incluso en teselas de frontera compartidas.

El extracto OSM de Geofabrik genera un intermedio que se recorta por nodos y segmentos completos al límite de RD. Solo el grafo nacional resultante se incluye en assets/routing. IslandRoutingService lo abre en un isolate persistente y IslandGraph calcula A* con cola de prioridad e índice espacial. Se usa para recorridos con al menos un punto fuera del piloto; el motor inicial se conserva para ambos puntos dentro de Ciudad Colonial. No se requieren servicios remotos. Preparación reproducible en tools/dominican_region/README.md.

El mapa conserva una clave estable, un espacio fijo para instrucciones y la misma instancia del mapa base entre selecciones. Una capa de gestos coloca el punto al soltar un toque, sin esperar reconocimiento de doble toque; la capa deja que el mapa reconozca arrastre y zoom. Solo los marcadores cambian; la cartografía y cámara se conservan. El cálculo asíncrono descarta respuestas obsoletas si cambian los puntos.

La primera mejora de fase 7 añade favoritos locales mediante repositorio,
controlador y panel independientes en lib/features/favorites. Reutiliza
shared_preferences, con clave distinta del modo oscuro. Los registros contienen
referencias a la región/versión y al ID del lugar; el panel resuelve los nombres
y coordenadas vigentes desde RegionData, sin duplicar el estado del mapa.
Solo elegir un favorito como A/B utiliza el HomeController existente. Los
errores de lectura/escritura tienen recuperación visible y los lugares retirados
de los datos no se pueden seleccionar. La mejora se desarrolla en feat/favorites,
manteniendo main y mvp-v0.1.0 como base estable para la revisión posterior.
