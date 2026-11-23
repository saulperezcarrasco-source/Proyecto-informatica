import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('ruta automática de RD, puntos inmediatos y exclusión de Haití', (
    tester,
  ) async {
    final c = HomeController();
    await c.retry();
    expect(c.state, RegionState.ready);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(controller: c)));
    await tester.pumpAndSettle();
    final finder = find.byType(FlutterMap);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final element = tester.element(finder);
    final top = tester.getTopLeft(finder);
    final baseFinder = find.byKey(const ValueKey('island-basemap'));
    // pumpAndSettle does not wait for filesystem/plugin futures when no
    // animation is scheduled. Let the real local archive finish opening.
    for (var i = 0; i < 300 && baseFinder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.text('Reparar mapa de RD').evaluate().isNotEmpty) break;
    }
    expect(baseFinder, findsOneWidget);
    final base = tester.widget(baseFinder);
    final map = tester.widget<FlutterMap>(finder).mapController!;
    final center = map.camera.center, zoom = map.camera.zoom;
    for (final choice in [
      (Selection.origin, const LatLng(19.54878, -71.70829)),
      (Selection.destination, const LatLng(19.4517, -70.697)),
    ]) {
      // Two direct taps assign A then B, with no mode or calculate buttons.
      await tester.pump();
      final target = map.camera.latLngToScreenOffset(choice.$2);
      await tester.tapAt(tester.getTopLeft(finder) + target);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        choice.$1 == Selection.origin ? c.origin : c.destination,
        isNotNull,
      );
      expect(tester.element(finder), same(element));
      expect(tester.widget(baseFinder), same(base));
      expect(tester.getTopLeft(finder), top);
      expect(map.camera.center, center);
      expect(map.camera.zoom, zoom);
    }
    // Selecting B must start calculation without pressing a separate button.
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      while (c.calculating && watch.elapsed < const Duration(seconds: 60)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    expect(
      c.route,
      isNotNull,
      reason: '${c.message}\n${c.islandRouting.diagnostic}',
    );
    expect(c.route!.distanceMeters, greaterThan(100000));
    expect(c.route!.coordinates.length, greaterThan(1000));
    expect(
      tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .any(
            (layer) => layer.polylines.any(
              (line) =>
                  line.color == Colors.blue &&
                  line.points.length == c.route!.coordinates.length,
            ),
          ),
      isTrue,
    );
    debugPrint(
      'ISLAND_ANDROID distance=${c.route!.distanceMeters} vertices=${c.route!.coordinates.length} elapsedMs=${c.calculationMilliseconds} approachA=${c.route!.originApproachMeters} approachB=${c.route!.destinationApproachMeters}',
    );
    final previousRoute = c.route!;
    final newEnd =
        previousRoute.coordinates[previousRoute.coordinates.length ~/ 2];
    c.chooseOnMap(Selection.destination);
    await tester.pump();
    final target = map.camera.latLngToScreenOffset(
      LatLng(newEnd.lat, newEnd.lon),
    );
    await tester.tapAt(tester.getTopLeft(finder) + target);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      while (c.calculating && watch.elapsed < const Duration(seconds: 60)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    expect(c.route, isNotNull, reason: c.message);
    expect(identical(c.route, previousRoute), isFalse);
    expect(c.route!.distanceMeters, lessThan(previousRoute.distanceMeters));
    await tester.ensureVisible(find.byTooltip('Detalles de ruta'));
    await tester.tap(find.byTooltip('Detalles de ruta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Borrar ruta'));
    await tester.tap(find.text('Borrar ruta'));
    await tester.pumpAndSettle();
    expect(c.route, isNull);
    expect(c.origin, isNotNull);
    expect(c.destination, isNotNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
