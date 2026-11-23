# Interfaz sin menú inferior — 1.4.0-demo+8

Solicitud del 23/11/2026: quitar todo lo que aparece debajo del mapa y mejorar
la claridad de la pantalla. El mapa es el último contenido de planificación;
se retiraron el panel «Tu recorrido», las coordenadas y el pie de datos.

El encabezado reúne ubicación, favoritos y tema. Búsqueda, transportes,
tarjetas A/B y la acción de calcular/iniciar navegación aparecen arriba.
Los detalles de aproximación y «Borrar ruta» se abren desde «Detalles de ruta».
La estrella abre los favoritos guardados, con selección de origen o destino.
Los créditos quedan encima del mapa, sin recuadro en el lienzo. La pantalla de
navegación también elimina el pie inferior de créditos.

Validación local: análisis sin incidencias y 63 pruebas aprobadas, incluyendo
pantallas pequeñas con texto al 200 % y selección inmediata sin recrear el mapa.
En Pixel_10a / Android API 37 pasaron los fixtures AOT `mobility_test.dart`
y `planning_controls_test.dart`: cuatro modos con distintos tiempos y mismo
estado del mapa; favoritos guardados/reabiertos, selección A/B y eliminación
sin alterar la ruta; tres rutas piloto, detalles, borrar y recuperación de
errores. El fixture de favoritos invoca el callback de búsqueda: la inyección
de texto de `tester.enterText` no entregó resultados en este emulador. La
escritura con teclado nativo se comprueba por separado sobre el APK normal.

Entrega normal instalada mediante `tools/build_phone.ps1` / `run_android.ps1`.
La comprobación nativa con adb/uiautomator pasó: escribir «cafe», seleccionar
Café Conde de Peñalba y Café La Moricette, ruta azul automática de 166 m,
abrir/cerrar detalles y favoritos, cambiar al tema oscuro y abrir/salir de
navegación. Navegación se revisó visualmente esperando GPS; no se midió un
recorrido en movimiento en esta actualización.

APK universal de 207.957.746 bytes, código `e3a599669f4cc9efe534457c954df89daa5e0caf`.
SHA256 `feb522537c41d61ba6d349e3a851911a179d3e6317d9262a7a3f1b2f39393774`.
El APK extraído del emulador coincide por SHA256 con el entregado. Firma,
arquitecturas ARM32/ARM64/x64 y alineación ZIP/ELF de 16 KB comprobadas.

Capturas: [inicio](interfaz-inicio.png), [ruta](interfaz-ruta.png),
[detalles](interfaz-detalles.png), [favoritos](interfaz-favoritos.png),
[tema oscuro](interfaz-tema.png), [navegación](interfaz-navegacion.png).

Sin cambios de catálogo, grafos ni algoritmo GPS. No se presenta como una
prueba en teléfono físico ni se garantiza la cobertura de todos los negocios.
