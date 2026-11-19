# Arquitectura y alcance

Ruta RD Offline es una aplicación Android peatonal que incluirá los datos de una zona piloto para funcionar desde la primera apertura sin conexión. La ruta será la de menor distancia en el grafo disponible; no representa seguridad ni accesibilidad. No incluye backend ni servicios remotos en ejecución.

Zona piloto inicial: rectángulo geográfico de la Ciudad Colonial de Santo Domingo entre 18.4700 y 18.4780 de latitud norte y -69.8900 y -69.8800 de longitud. Es el límite de trabajo para preparar el extracto; la cobertura transitable y la exactitud de los datos deberán revisarse en la fase 2.

La interfaz Flutter usará ChangeNotifier; la carga local, la búsqueda y el cálculo de rutas estarán separados. El motor de rutas será Dart puro. Las geometrías y el grafo vendrán de assets; el prototipo web es solo referencia visual y sus conexiones no son cartografía real.
