# Navegación y búsqueda nacional — 1.6.0-demo+12

La navegación usa GPS satelital directo en Android y sigue esperando la primera
posición sin cortarse a los 15 segundos. Activar «Usar ubicación precisa» en los
permisos de Ruta RD Offline y mantener la ubicación del teléfono encendida.
Los botones de error abren los ajustes correspondientes. Sin buena recepción
puede tardar en obtener una lectura fiable; la app muestra su estado y no inventa
avance con señales imprecisas. El seguimiento se pausa en segundo plano y se
reanuda al regresar, conservando una pausa elegida manualmente.

La pantalla principal permanece fija y el mapa ocupa el espacio libre. Las
coincidencias de búsqueda se recorren dentro de su propio panel. Con teclado
o pantallas pequeñas, los controles se compactan; el transporte está en el
menú «Transporte», o en «Más opciones» en horizontal con poca altura.

Instalar el APK universal como actualización. Incluye ARM32, ARM64 y x64.
Elegir **A pie**, **Bici**, **Coche** o **Moto**. Cada modo usa su propia red
de vías OSM y recalcula al cambiarlo, conservando origen/destino. Se busca la
menor distancia disponible para ese perfil, no la ruta más rápida según tráfico.
El tiempo usa velocidades orientativas de 4,5 / 15 / 40 / 35 km/h,
respectivamente. Las aproximaciones naranjas siguen sin verificarse.

Las redes de bici/coche/moto filtran accesos, barreras y sentidos registrados;
incluyen restricciones de giro con nodo intermedio. Las restricciones complejas
con vías intermedias se evitan; vías con sentidos variables por horario también
se excluyen. No se evalúan todos los regímenes legales posibles, carriles,
límites vigentes ni cierres. Los datos OSM pueden estar incompletos o cambiar:
respetar las señales del lugar. No hay tráfico en tiempo real ni guía por voz.

Buscar en **Elegir origen** y **Elegir destino**, y tocar un resultado de cada
campo. También se puede usar el icono de mapa de cada entrada para colocar su
punto manualmente. Con ambos puntos se calcula la ruta automáticamente.
El mapa solo coloca puntos tras activar ese icono: los toques normales no
alteran el origen ni el destino, y la selección se desactiva al colocar uno.
Encima del mapa, pulsar **Iniciar navegación**. Conceder el permiso de ubicación
y activar GPS. La vista ampliada muestra una flecha azul en la posición GPS,
orientada por rumbo GPS o dirección del desplazamiento, y distancia/minutos
restantes. La flecha no es una brújula del teléfono cuando estás quieto.

La distancia se actualiza al avanzar sobre el recorrido; no se vuelve a
calcular todo el grafo por cada posición. Se muestran avisos de señal imprecisa
y salida de ruta. Fuera del recorrido, usar **Recalcular desde mi posición**:
vuelve al mapa y calcula una ruta nueva; después se puede iniciar navegación.
Las indicaciones de giro se deducen de la geometría y no incluyen nombres de
calles ni información de tránsito. No garantizan transitabilidad en terreno.

Desde 1.000 m se muestran kilómetros: 1 km, 1.1 km, 1.5 km, etc. La distancia
incluye el progreso por las aproximaciones a origen/destino. Retroceder aumenta
lo que queda. Lecturas con precisión peor de 35 m muestran ubicación aproximada
en naranja hasta 200 m de incertidumbre, sin avanzar la ruta ni confirmar llegada.
Con mayor incertidumbre se conserva la última posición conocida. Se descartan
lecturas antiguas/futuras, duplicadas y saltos imposibles. La continuidad
de avance ayuda a evitar saltos a otro tramo cercano en cruces. Estas medidas
no mejoran por sí solas la precisión física del receptor GPS.

La vista de navegación se centra a nivel de calle al recibir posición GPS para mantener visible la línea
azul en recorridos cortos. Sus controles reemplazan los botones del mapa de
planificación. La versión 1.1 se midió en REVVL 7/Android 16; para esta 1.6 el
usuario eligió continuar las verificaciones en emulador. Falta comprobar una
caminata con GPS físico con esta actualización.

Arrastrar o ampliar el mapa desactiva el seguimiento de cámara. **Seguir mi
posición** vuelve a centrar. **Pausar** detiene GPS; **Continuar** lo reinicia.
Salir de navegación o enviar la app al fondo detiene el seguimiento; al volver
se reanuda salvo si se pausó manualmente. No se solicita ubicación al abrir la aplicación ni
se implementa navegación en segundo plano. La ruta y A/B elegidos se conservan;
la flecha representa la ubicación actual, no un cambio de destino.
La cámara acompaña posiciones con una transición de 180 ms y omite movimientos
menores de 0,5 m; arrastrar cancela esa animación. El rumbo interpola el ángulo más
corto y mantiene la indicación de giro hasta 5 m después del vértice. El tiempo restante
puede ajustarse a movimiento GPS reciente y fiable; parado conserva la referencia.

La búsqueda nacional usa 96.873 registros OSM, incluidos tramos de
calles, barrios, negocios y turismo del extracto del 18/11/2026, recortado a RD.
De ellos, 1.635 locales/servicios sin nombre registrado se identifican por su
categoría y “(sin nombre)”; no se inventan marcas ni nombres comerciales.
Escribir al menos dos caracteres; permite acentos, palabras en distinto orden
y contexto de ciudad cercana, sin internet. Por ejemplo, “monumento de Santiago”
encuentra el Monumento a los Héroes de la Restauración. También permite buscar
negocios, turismo y otros lugares del catálogo en todo el país.
No equivale a 96.873 negocios únicos: una calle puede tener varios tramos y
hay nombres repetidos. No garantiza todos los lugares existentes ni la misma
cobertura que Google Maps. Al acercar aparecen etiquetas seleccionables de
turismo desde zoom 14 y locales desde 15, con límite de 45 para evitar saturar
la vista. Las teselas mantienen los nombres de calles/barrios. No dibuja
96.873 widgets a la vez. La búsqueda no descarga
resultados remotos. Fuente y licencia: © OpenStreetMap contributors, ODbL 1.0;
consultar datos-busqueda.json y DATOS-Y-LICENCIAS.md.

Para reducir trabajo durante zoom/pan, las etiquetas se rasterizan por tesela
y se reutilizan con caché adaptada a pantalla/densidad. Pueden escalar durante
el zoom y algunas se omiten cerca del borde de una tesela. El rendimiento real
depende del teléfono; las pruebas del emulador no sustituyen su medición.
