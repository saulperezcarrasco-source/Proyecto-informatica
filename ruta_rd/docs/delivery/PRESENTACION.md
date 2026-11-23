# Guion de demostración — cinco minutos

Preparar Pixel_10a con el APK de esta carpeta. Tener respaldo.mp4 listo para
reproducir si falla la proyección. La captura no tiene narración: acompañarla
con este guion. No confundir el GPS inyectado del emulador con una medición física.
Las ocho diapositivas están en PRESENTACION.html (abrir localmente y usar las
flechas del teclado) y en su exportación PRESENTACION.pdf para proyección.

| Tiempo | Acción y explicación |
|---|---|
| 0:00–0:30 | Presentar Ruta RD Offline: consultar mapa y calcular recorridos peatonales con datos incluidos, sin depender de conexión durante el uso. |
| 0:30–1:00 | Mostrar la vista nacional de RD y atribución. Aclarar que la búsqueda por nombres disponible es la de Ciudad Colonial. |
| 1:00–1:40 | Mostrar modo avión y Wi-Fi apagado. Abrir la app. Explicar que la primera apertura lee datos locales; no descarga teselas. |
| 1:40–2:40 | Buscar cafe, elegir un lugar como A y otro como B. Mostrar que la línea azul aparece automáticamente y leer distancia, estimación peatonal y accesos separados. |
| 2:40–3:25 | Guardar dos estrellas, abrir Favoritos y elegir un guardado. Cerrar/reabrir para mostrar persistencia. Quitar uno conservando la ruta. |
| 3:25–4:00 | Pulsar Mi ubicación. Mostrar permiso rechazado y la alternativa por texto o mapa. Identificar cualquier posición inyectada como simulada. |
| 4:00–4:40 | Mostrar modo oscuro y Ver toda RD. Explicar límites: nombres del piloto, datos OSM, recorridos peatonales, accesos sin verificar, sin tráfico ni garantía de accesibilidad. |
| 4:40–5:00 | Cerrar con lo comprobado: APK final instalado, uso offline, favoritos y errores recuperables. Próximas mejoras posibles: filtros, accesibilidad y validación física, fuera de esta entrega. |

## Preparación y respaldo

- Revisar manifest.json y SHA256SUMS.txt; usar el APK exacto del paquete.
- Permitir que termine la carga del mapa antes de tocar controles.
- Si un lugar no tiene camino o conexión, explicar el error y corregir el punto;
  no presentar una línea artificial como ruta real.
- Mantener a mano INSTALAR.md, DATOS-Y-LICENCIAS.md y el video de respaldo.
- La entrega congela las funciones seleccionadas del MVP y favoritos. El plan
  del proyecto reserva el 2 de diciembre para congelación general y el 3 de
  diciembre para correcciones críticas; no se programan despliegues automáticos.
