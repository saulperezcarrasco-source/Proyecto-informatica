# Funciones integradas

19 de noviembre de 2026. Solicitud del usuario: habilitar búsqueda y botones y completar pendientes anteriores. Se amplió el alcance a la integración inicial de búsqueda, rutas y GPS.

Implementado: carga validada de assets, polígonos locales y marcadores, búsqueda normalizada con diez resultados y orden estable, elección textual y manual A/B, errores de cobertura, Dijkstra dirigido, aproximaciones separadas, resumen de distancia/tiempo, GPS puntual con permisos y espera máxima, limpieza y centrado del mapa. Sin servicios cartográficos remotos.

`flutter analyze`: sin problemas. `flutter test`: ocho pruebas aprobadas. Cubren assets reales, normalización, Dijkstra, desconexión, origen igual al destino, punto lejos del grafo, conservación de selección, GPS con servicio falso, búsqueda y limpieza de pantalla y diseño pequeño/horizontal con texto grande.

Android 17 emulado: aplicación compilada e instalada. Búsqueda `cafe` devuelve lugares ([captura](busqueda.png)); selección de Café Conde de Peñalba y Café La Moricette y cálculo de 166 m / 3 minutos aproximados ([captura](ruta.png)). Aproximaciones mostradas: 20 m y 24 m. Se abrió la solicitud de permiso GPS y se recibió una posición que la app rechazó por estar fuera de cobertura ([captura](gps.png)). El comando de simulación se envió dentro de cobertura, pero la posición recibida no coincidió; no se afirma éxito dentro de la región ni prueba de GPS físico.

Pendientes: pruebas exhaustivas de JSON inválido/archivos ausentes, revisión de cinco lugares y cinco conexiones frente a la fuente, restricciones ambiguas y cartografía, prueba de instalación limpia sin red, tres rutas reales revisadas, permisos GPS denegados/permanentes y dispositivo físico. No se declaran aceptadas las fases 2–5.
