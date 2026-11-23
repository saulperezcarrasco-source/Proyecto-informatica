# Logo, cuatro transportes y navegación — 1.3.0-demo+6

20/11/2026 (fecha local). Solicitud: logo 1.png en icono/inicio grande, iconos
distintos para origen/destino, nuevo texto de instrucciones, cuatro transportes
con tiempos diferentes, más locales y mejoras adicionales de navegación.

## Implementación

El PNG original se conserva intacto. El símbolo transparente se preparó con
imagegen incorporado; prompt y archivos en assets/brand/README.md. Recursos
Android de densidad y adaptativos, monocromo solo desde API 33, splash nativo
y logo completo en Flutter durante la preparación. Un mínimo visual de 900 ms
permite reconocer la identidad mientras HomeScreen carga en paralelo; transición
de 250 ms, respetando desactivación de animaciones. Origen usa círculo/centro,
destino bandera/recuadro; formas, colores y semántica distintos en mapa/resumen.
El texto solicitado se mide y reserva espacio para evitar mover el mapa al tocar.

TravelMode selecciona perfiles reales separados, conservando A/B y descartando
respuestas viejas. A pie conserva piloto/RDI1; bici/coche/moto usan RDI2 del PBF
OSM fijado, recortado por nodos y segmentos completos al país. El worker previo
se libera al cambiar modo. Filtros de acceso, barreras y sentido; 204 restricciones
de giro para bici y 221 para coche/moto, resueltas por A* con arista entrante.
Se evitan 32 vías de restricciones complejas via-way. Un pase final eliminó
14 aristas por perfil por sentidos temporales, sin asumir horarios; motorroad
sin permiso de bici se excluye. Manifiestos y hashes por perfil incluidos.
Velocidades de referencia: 4,5/15/40/35 km/h. Ruta de menor distancia por perfil,
no optimización por tráfico ni certificación de señalización/regulación en campo.

La cámara interpola 450 ms, omite desplazamientos <2 m y cancela al arrastrar.
Rumbo suavizado por ángulo corto; las instrucciones de giro se mantienen hasta
3 m. ETA restante se puede ajustar solo con lecturas recientes de buena precisión
y movimiento plausible; los accesos al grafo se estiman a pie separadamente.
Se mantienen descarte de señales pobres/saltos, pausa/fondo y retorno a ruta.

El catálogo añade **1.755 registros**, total **96.873**, más 190 del piloto.
1.635 están sin nombre en OSM y se muestran con categoría + “(sin nombre)”; se
incluyen nombres de operador cuando corresponden. No se inventan comercios.
IDs/versiones previas de favoritos se conservan. La cobertura no equivale a Google.

## Pruebas durante desarrollo

Análisis limpio, 61 pruebas locales y cuatro pruebas Python de políticas
aprobadas antes de la comprobación adicional de perfiles filtrados.
La prueba AOT del emulador verificó logo original, instrucciones, cuatro chips,
A/B conservados, mapa sin recreación y lugares adicionales. Caso Santiago–Puerto
Plata: a pie 56.808 m / 757,4 min; bici 57.765 m / 231,1 min; coche 57.765 m /
86,6 min; moto 57.765 m / 99,0 min. Cálculo/carga en ese emulador: 0,60–0,71 s.
Esa primera prueba precede al pase temporal; la validación final usa los assets
filtrados y sus hashes actualizados.

La prueba AOT de navegación posterior al filtrado validó etiquetas/tocar POI,
flecha, avance, pausa, seguimiento y llegada. 120 movimientos de cámara con
scheduler continuo: 68 muestras, UI media 7,04 ms/P90 9,25 ms (0 >16,67 ms),
raster media 12,80 ms/P90 20,65 ms. Las posiciones de esta prueba son inyectadas
a nivel de servicio. No es GPS físico ni una comparación con rendimiento del
teléfono. Ambas pruebas y sus teardown finalizaron en “All tests passed”.

El APK normal debe reinstalarse después de los fixtures. La instalación,
verificación del archivo universal y comprobaciones nativas finales se registran
al terminar la entrega. Las mediciones de REVVL 7 de 1.1 son antecedentes; esta
versión se comprueba en emulador por elección del usuario.

Revisión final antes de compilar: **62 pruebas locales aprobadas**, análisis
limpio y cuatro pruebas Python de políticas aprobadas. Los tres perfiles con el
pase temporal definitivo calcularon ida y vuelta: bici 57.765/57.847 m,
coche 57.765/57.847 m, moto 57.765/57.847 m, con tiempos de sus propios modos.

La revisión visual del APK detectó un estilo heredado incorrecto en el texto del
splash Flutter. Se añadió Material como ancestro y el mínimo de 900 ms se cuenta
desde el primer fotograma. Una regresión comprueba tamaño/ausencia de subrayado
y transición al mapa. Análisis limpio y **63 pruebas locales aprobadas** tras
esa corrección. El problema estaba en la presentación de carga; los perfiles,
el catálogo y el seguimiento GPS no cambiaron.

## APK normal comprobado antes del último ajuste del mensaje

Compilado desde `74b0819e56356518a13792d4920800eba7409d36`, versión
1.3.0-demo+6. Universal ARM32/ARM64/x64, 207.957.582 bytes. SHA256:
`9ca66b4c8b4cc2205da05839d93511dc8b8a42ff575a5008fd42adac6410a749`.
Firma, ABI completas, alineación ZIP/ELF 16 KB y hashes del catálogo y de los
tres perfiles RDI2 aprobados. Instalado mediante tools/run_android.ps1 -SkipBuild.
Android confirma versionCode=6 y el base.apk instalado tiene el mismo hash.
La captura de inicio corregida muestra logo completo grande y texto Material
normal, sin el subrayado del primer candidato. La aplicación vuelve después al
mapa con los cuatro modos y el nuevo mensaje visibles.

El APK definitivo, con GNSS nativo inyectado del emulador y sin conexión,
actualizó **189 → 106 → 0 m** y confirmó llegada. Se repitieron por interfaz
nativa los cuatro modos para Monumento de Santiago → Puerto Plata:

| Modo | Distancia sobre vías | Estimación |
|---|---|---|
| A pie | 57.5 km | 767 min |
| Bici | 58.7 km | 235 min |
| Coche | 58.5 km | 88 min |
| Moto | 58.5 km | 101 min |

Las coordenadas del destino se comprobaron para asegurar la selección de la
ciudad. También se verificaron búsqueda de “Colmado sin nombre Santiago”,
marcadores del recorrido corto Monumento–Busto a Mamoru Matsunaga y modo oscuro.
Un ajuste del guion de pruebas corrigió la detección de teclado: las interacciones
se restringen al paquete Ruta RD y no se toma una vista IME almacenada como
evidencia de teclado visible. No requirió cambios de aplicación.

Los resultados completos, actas y capturas se adjuntan con prefijo movilidad-.
No se probó esta actualización en un teléfono físico. Los datos de GPS y las
mediciones de frames corresponden solo al emulador identificado.

La corrección posterior del usuario pidió explicitar “Primero” y “Por último”.
El texto ahora separa esos pasos con saltos de línea. Análisis limpio y nueve
pruebas de interfaz aprobadas tras el cambio, incluyendo texto grande y posición
inmediata sin mover el mapa. La entrega se reconstruye con ese texto; el
manifiesto final identifica el nuevo commit compilado y hash.

Entrega final con Primero/Por último: commit compilado 1531f1a9b72da03079b85160912af70f2092d117.
SHA256 APK: 73a53060f055155d7085f260674470068460037fb66e8badf6887b118c6ccaab. El hash del APK instalado coincide.
Texto confirmado por interfaz Android y captura movilidad-mensaje-final.png.
Icono confirmado visualmente en la información de la aplicación de Android.
La última modificación afecta solo al mensaje; sus nueve pruebas de interfaz pasan.
