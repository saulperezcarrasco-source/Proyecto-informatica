# Navegación y lugares nacionales — 1.2.0-demo+5

20/11/2026. Ampliación solicitada: navegación más precisa, negocios/turismo y
etiquetas en todo RD, búsqueda del Monumento de Santiago, unidades m/km y retiro
del aviso desde “Tiempo estimado” hasta “revisión final”. El usuario eligió
continuar con el emulador; no se atribuyen estas verificaciones a un teléfono.

## Implementación

El catálogo mantiene 95.118 IDs OSM únicos, extraídos del PBF fijado del
18/11/2026: calles, barrios, negocios, servicios, turismo y otros lugares.
Revisión 2: alias locales y contexto de ciudad OSM más cercana hasta 25 km,
identificado como proximidad y no como dirección postal. Las consultas combinan
palabras en distinto orden. “Monumento de Santiago” encuentra el registro
rd:way:191967205, Monumento a los Héroes de la Restauración; “Sirena Santiago”
combina el negocio con su contexto. No se limita la mejora a ese monumento.
Los datos siguen siendo OSM, sin copiar ni prometer la cobertura de Google Maps.

El mapa muestra locales seleccionables por canvas, índice geográfico de 0,01°,
160 candidatos y máximo 45 etiquetas; turismo desde zoom 14, otros locales desde
15. Conserva nombres de calles/ciudades de teselas y atribución. No instancia
95.118 widgets. Las etiquetas solapadas se omiten y los nombres largos se
abrevian visualmente; la selección/búsqueda conserva el nombre completo.

La navegación indexa segmentos, limita saltos a tramos futuros en cruces,
rechaza precisión >35 m, lecturas antiguas/futuras y desplazamientos imposibles.
Admite retrocesos reales y progreso por las aproximaciones a A/B. No ejecuta A*
por cada fix y conserva la ruta original. La precisión física del GPS y una
caminata real quedan pendientes. Los accesos naranjas siguen sin verificarse.

Las distancias muestran m hasta 999 y km desde 1.000: 1 km, 1.1 km, etc.
Se retiró el mensaje solicitado; se conserva la leyenda de accesos naranjas.

## Verificación previa al APK final

Formato sin cambios, flutter analyze sin incidencias y 57 pruebas locales
aprobadas. Incluyen búsqueda nacional de calles/negocios/turismo, kilómetros,
retroceso, señal pobre, saltos, acceso final, cruces y proyección indexada.

Prueba AOT profile en Pixel_10a, emulator-5554, Android 17/API 37: catálogo real,
búsqueda de Monumento de Santiago, 13 etiquetas pintadas en su entorno,
selección por toque de Busto a Mamoru Matsunaga como B, ausencia del aviso,
flecha visible a zoom 17, avance/pausa/continuación/llegada y ruta conservada.
Posiciones inyectadas en la frontera de LocationService, no GPS físico.
120 movimientos de cámara con scheduler continuo: 90 muestras, UI media
5,69 ms/P90 12,06 ms (0 >16,67 ms); raster media 15,79 ms/P90 22,19 ms.
Son mediciones de este emulador, sin afirmar equivalencia con un teléfono.
El fixture y su teardown terminaron con “All tests passed”.
La medición AOT corresponde a 44d3564, antes del ajuste posterior de orden de
resultados; ese ajuste no modifica el mapa ni la navegación. Se repitieron
análisis y las 57 pruebas tras priorizar el nombre propio sobre alias/dirección.
La regresión exige que Puerto Plata devuelva primero rd:node:11610553782.

## APK normal y GNSS Android

Compilado desde f44b258997746923ddbd42194855170ce4385ab6. APK universal normal
1.2.0-demo+5, 139.544.072 bytes; SHA256:
`2d0e4c7e2b12b4c6772c2554d45fd2774b693a30896e9722682edd99c9d20f2e`.
Validación de firma, ARM32/ARM64/x64 completas, catálogo/hash y alineación
ZIP/ELF 16 KB aprobada. Reinstalado con tools/run_android.ps1 -SkipBuild,
arranque en frío y proceso activo confirmados; reemplaza al fixture de pruebas.

El APK normal, sin conexión y con GNSS Android inyectado por adb emu geo fix,
actualizó **189 → 105 → 0 m**, mostró la flecha y confirmó llegada. No es una
caminata ni recepción satelital física. Después se restauraron red/datos del
emulador. Una desconexión posterior del AVD exigió abrirlo de nuevo en frío;
la instalación del mismo APK y su arranque volvieron a completarse.

En el APK definitivo se repitió por interfaz nativa la búsqueda de “monumento
de santiago”, “Sirena Santiago”, “Salto El Limon” y “Puerto Plata”. Se confirmó
la etiqueta del Monumento, negocios por ciudad y turismo fuera de Santiago.
La ruta automática desde el Monumento hasta Puerto Plata (nodo OSM
11610553782, 19.7976564/-70.6932607) mostró **57.5 km**; se comprobaron las
coordenadas del destino para no confundir la ciudad con un comercio cuya
dirección la menciona. El aviso solicitado ya no aparece.

En navegación se confirmó **57.6 km restantes** (incluye accesos). Se verificó
una ruta corta Monumento–Busto a Mamoru Matsunaga, las etiquetas en modo oscuro
y el panel de origen/destino al tocar un lugar con ambos puntos ya elegidos.
Se volvió a modo claro, con el APK normal abierto y el trazado azul visible.
Registro: precision-details-acta.json y capturas de navegación/oscuro/opciones.

El hash del base.apk instalado coincide con el APK entregado. Los registros
están en precision-resultados.txt, precision-gps-acta.json y
precision-release-acta.json; las capturas adjuntas muestran locales, búsqueda,
avance GPS y unidades. El paquete conserva tres ABI pero esta actualización
se ejecutó únicamente en el emulador Android 17/API 37. No se afirma validación
en todos los teléfonos ni caminata con receptor físico.
