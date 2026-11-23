# Dos campos de búsqueda — 1.4.1-demo+9

23/11/2026. Solicitud: sustituir «Buscar un lugar» por dos entradas de origen y
destino, conservándolo como ejemplo de búsqueda; eliminar las instrucciones
encima del mapa.

Se muestran «Elegir origen» y «Elegir destino», con «Buscar un lugar» como pista.
Los resultados se asignan únicamente al campo activo. Cada campo permite borrar
su punto o elegirlo sobre el mapa, con iconos A/B distintos. Las selecciones de
mapa, ubicación y favoritos se reflejan en estas mismas entradas. Al editar un
punto se descarta su ruta anterior y se conserva el otro; se calcula de nuevo
al seleccionar ambos. Editar el origen cancela una consulta GPS pendiente.
Se retiran las instrucciones fijas y las tarjetas duplicadas de A/B.
Tocar el mapa o un negocio ya no selecciona puntos automáticamente. Primero
se activa el icono de mapa del origen o del destino; el siguiente toque coloca
solo ese punto y desactiva la selección. El icono activo permite cancelarla.

Validación local: análisis sin incidencias y 63 pruebas aprobadas de búsqueda A/B, ruta
automática, edición de un solo extremo, limpieza y sincronización desde el
controlador; regresión de GPS tardío durante edición. También se conservan las
pruebas de texto grande y punto inmediato sin reconstruir el mapa. La revisión
nativa de la entrega se completó sobre el APK normal en Pixel_10a, API 37.

Con adb/uiautomator pasaron: dos entradas visibles y sin instrucciones, toque
normal sin crear puntos, activar origen y colocar solo A, segundo toque sin
crear B, búsqueda con teclado Android en cada campo y ruta automática de 166 m
entre Café Conde de Peñalba y Café La Moricette. Una búsqueda sin resultados al
editar A conserva B y descarta la ruta antigua; elegir otro origen recalcula
automáticamente. También se comprobaron cambio a coche y cambio de tema.

APK universal instalado con `tools/build_phone.ps1` / `run_android.ps1`.
Código compilado local: `3f143f34622e123e149c246b2902a066992611f0`.
207.957.878 bytes, SHA256:
`1cb6119382e1c59dc4983f4ed73c1306f3ade25d837ca15bce499867e5f95f69`.
Verificaciones estáticas de firma, tres ABI y alineación ZIP/ELF de 16 KB pasadas.

Capturas: [inicio](busqueda-doble-inicio.png),
[selección explícita](busqueda-doble-mapa-explicito.png),
[ruta](busqueda-doble-ruta.png), [recálculo](busqueda-doble-recalculo.png),
[tema](busqueda-doble-tema.png).

No se modificaron catálogo, grafos ni navegación GPS. Esta actualización se
valida en emulador, sin afirmar pruebas en un teléfono físico.
