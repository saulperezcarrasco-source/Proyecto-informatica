# Modo oscuro y mapa nacional

19 de noviembre de 2026. Ampliación de alcance solicitada por el usuario.

Modo claro/oscuro con preferencia local persistente, tema inicial del sistema y transición de 250 ms que respeta reducción de animaciones. Botón de cambio en el encabezado. Mapa, polígonos, textos y atribución se adaptan al tema. Las etiquetas nocturnas del estilo se ajustaron localmente para aumentar su contraste.

Archivo offline nacional de 58.474.685 bytes: extracto Protomaps/OSM de 18 de noviembre de 2026, bbox -72.05,17.3,-68.2,20.1. Incluye RD y bordes vecinos del recorte. Teselas nativas 0–15, ampliables en pantalla hasta 19. El nivel de detalle depende del zoom y de los datos cartográficos de la fuente.

La aplicación incluye el archivo y los estilos en assets. En el primer uso copia el archivo al almacenamiento privado para leer intervalos de bytes sin cargar el país completo en memoria. El adaptador LocalArchiveClient atiende todas las lecturas desde File; su URL de identificación .invalid no genera solicitudes de red. Los estilos se compilan con ThemeReader y no se descargan fuentes ni sprites externos; los textos usan las fuentes disponibles en la aplicación.

La visualización nacional no amplía el grafo ni el índice de lugares: búsqueda y rutas siguen disponibles en la zona piloto, como se indica debajo del mapa. Para ver el país se añadió Ver toda RD y se permite alejar el mapa.

Regeneración: `powershell -ExecutionPolicy Bypass -File tools/national_map/prepare.ps1`. Formato, procedencia, versiones y SHA-256 en `assets/national/manifest.json`; licencia del estilo incluida. Datos OSM bajo ODbL: https://www.openstreetmap.org/copyright . Fuente y extracción: https://docs.protomaps.com/guide/getting-started .

Pruebas locales: 20 aprobadas, incluidas persistencia del tema, lectura de intervalos y rechazo de destinos remotos, y teselas reales de Santo Domingo, Santiago, Punta Cana, Puerto Plata y Barahona.

`flutter analyze`: sin problemas. `flutter test integration_test/theme_national_test.dart -d emulator-5554`: PASS con Wi-Fi y datos desactivados. Abrió la capa nacional, cambió ambos temas, comprobó preferencia persistente y visitó Santiago, Punta Cana y Barahona. Se verificó la vista general del país. La prueba Android tardó 54 s, incluyendo preparación/renderizado; no es una medición de navegación en teléfono físico.

La aplicación normal se reinstaló y abrió en el emulador. Se forzó su cierre y se volvió a abrir: conservó el modo oscuro. Se verificó la vista nacional con Wi-Fi y datos desactivados ([captura](rd-dark.png)) y luego se restauró la conexión anterior. Se dejó abierta esa vista para el usuario. La prueba local de las tres funciones nuevas volvió a pasar después del ajuste de contraste.
