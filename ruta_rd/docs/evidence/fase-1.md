# Evidencia de fase 1

Fecha: 19 de noviembre de 2026. Flutter 3.50.0; emulador Pixel_10a, Android 17. Commit: consultar historial.

- `dart format lib test`: completado.
- `flutter analyze`: sin problemas.
- `flutter test`: siete pruebas aprobadas, incluidos desplazamiento a los controles en tamaños vertical y horizontal con texto grande, simulación del espacio de teclado y entrada de texto en la pantalla de prueba.
- `flutter run -d emulator-5554`: compilación e instalación debug correctas; interfaz revisada en [captura](fase-1.png).
- Se reorganizó la interfaz con referencia a Waze: búsqueda superior, espacio principal para el mapa y panel de recorrido. El análisis y las tres pruebas volvieron a pasar. El diseño actualizado se ejecutó y revisó en el emulador: [captura actual](fase-1-actual.png).
- Se añadieron bordes redondeados y una transición de 250 ms entre estados, desactivada cuando el sistema solicita reducir animaciones. `flutter analyze` y las tres pruebas pasan. La captura anterior precede a este ajuste visual.
- La búsqueda está deshabilitada hasta la fase 3; no se puede abrir el teclado mediante ese campo. GPS, ruta y limpieza también están deshabilitados. El mapa es un marcador visual sin cartografía.
- En el emulador se probaron 840 × 1400 píxeles a 420 dpi y escala de texto 2.0 ([captura](fase1-pequena.png)), y rotación horizontal ([captura](fase1-horizontal.png)). La pantalla se desplaza; estas capturas muestran solo la parte visible y no demuestran por sí solas que todos los controles sean accesibles. Se restauraron los ajustes originales.
- El desplazamiento hasta los tres controles se comprobó en pantalla pequeña con texto al 200 % ([captura](fase1-controles.png)); el tamaño horizontal se verificó también mediante prueba de widgets. Los controles permanecen deshabilitados.
- Se ejecutó `flutter run -d emulator-5554 -t integration_test/keyboard_preview.dart`: el campo de prueba recibió texto y el teclado Android abrió; con él abierto se desplazó hasta los controles ([teclado](fase1-teclado.png), [controles](fase1-teclado-controles.png)). El fixture no implementa búsqueda; la app normal mantiene el campo deshabilitado.
- En horizontal se desplazó hasta los tres controles ([captura](fase1-horizontal-controles.png)). Se restauró la orientación del emulador y se volvió a instalar la aplicación normal.
- Fase 1 aceptada para la interfaz provisional. La búsqueda real y su prueba funcional corresponden a la fase 3.
