import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';
import 'package:ruta_rd/main.dart';

void main() {
  testWidgets('muestra interfaz y desactiva funciones pendientes', (
    tester,
  ) async {
    await tester.pumpWidget(const RutaRdApp());
    expect(find.text('Ruta RD Offline'), findsOneWidget);
    expect(find.text('Mapa pendiente de integrar'), findsOneWidget);
    final calculate = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Calcular ruta'),
    );
    expect(calculate.onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('muestra carga y permite reintentar un error', (tester) async {
    final controller = HomeController(state: RegionState.loading);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    expect(find.text('Cargando la región...'), findsOneWidget);
    controller.state = RegionState.error;
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('No se pudo cargar la región.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.text('Mapa pendiente de integrar'), findsOneWidget);
  });

  testWidgets('se adapta a pantalla pequeña y texto grande', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(320, 480),
          textScaler: TextScaler.linear(2),
        ),
        child: RutaRdApp(),
      ),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 480), const Size(640, 320)]) {
    testWidgets('controles accesibles al desplazarse en $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2),
            ),
            child: const HomeScreen(),
          ),
        ),
      );
      for (final label in ['Mi ubicación', 'Calcular ruta', 'Limpiar']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text(label)).overlaps(Offset.zero & size),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('el contenido sigue desplazable con espacio para teclado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 480),
            viewInsets: EdgeInsets.only(bottom: 220),
          ),
          child: HomeScreen(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Limpiar')).bottom, lessThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });
}
