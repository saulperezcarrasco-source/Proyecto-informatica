# Mapa sin recuadro — 1.3.1-demo+7

Solicitud: retirar el mensaje de OpenStreetMap del mapa sin añadir un botón
de información sobre la cartografía. LocalMap ya no contiene la capa de texto
de atribución. MapCredits se muestra fuera del canvas, debajo del mapa en
planificación y en la franja inferior de la pantalla de navegación. No añade
iconos dentro del mapa. El texto adyacente permite acceder a información de
origen y licencia sin necesitar conexión.

La ubicación adyacente conserva créditos conforme a la alternativa descrita
en las [guías de atribución de OSM](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines#Interactive_maps).
No cambian datos, perfiles de transporte, puntos ni cálculo de rutas.

Análisis y pruebas de interfaz/navegación se ejecutan antes de construir e
instalar el APK normal; las comprobaciones nativas finales se registran al
terminar la entrega.

Validación final: análisis limpio y 13 pruebas aprobadas. APK normal instalado
y revisado visualmente en planificación y navegación, sin recuadro ni iconos
de atribución dentro del canvas. Créditos adyacentes fuera de la cartografía.
Commit compilado: 76b077bae8e067fad87480e7a993389e6c828cdf. SHA256: 4593568c1846c217bdac4fc1e8d5296b858f648a3b53fc8de69f85460e3f7489.
El hash del APK instalado coincide con el archivo entregado. Solo emulador.
