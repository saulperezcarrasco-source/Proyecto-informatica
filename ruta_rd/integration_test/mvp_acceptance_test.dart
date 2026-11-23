import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';
import 'package:ruta_rd/features/location/location_service.dart';

// Deterministic denied-permission boundary, not a hardware GPS measurement.
class DeniedGps extends LocationService {
  int calls = 0;
  @override
  Future<LocationReading> getCurrentLocation() async {
    calls++;
    throw const LocationException(LocationFailure.permissionDenied);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('MVP: cargar, GPS rechazado, buscar, elegir, ruta y limpiar', (
    tester,
  ) async {
    final gps = DeniedGps();
    final controller = HomeController(location: gps);
    await controller.retry();
    expect(controller.state, RegionState.ready);
    expect(gps.calls, 0, reason: 'La apertura no debe depender del GPS');
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    final base = find.byKey(const ValueKey('island-basemap'));
    for (var i = 0; i < 300 && base.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(base, findsOneWidget);
    await controller.locate();
    await tester.pumpAndSettle();
    expect(controller.locationFailure, LocationFailure.permissionDenied);

    var search = find.byKey(const ValueKey('origin-search'));
    await tester.enterText(search, 'cafe');
    await tester.pumpAndSettle();
    expect(controller.results.length, greaterThan(1));
    await tester.ensureVisible(find.text('Usar como origen').first);
    await tester.tap(find.text('Usar como origen').first);
    await tester.pumpAndSettle();
    expect(controller.origin, isNotNull);
    search = find.byKey(const ValueKey('destination-search'));
    await tester.ensureVisible(search);
    await tester.tap(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'café');
    await tester.pumpAndSettle();
    expect(controller.query, 'café');
    expect(controller.results.length, greaterThan(1));
    await tester.ensureVisible(find.text('Usar como destino').last);
    await tester.tap(find.text('Usar como destino').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      while (controller.calculating && watch.elapsed.inSeconds < 60) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    expect(controller.route, isNotNull, reason: controller.message);
    expect(controller.route!.distanceMeters, greaterThan(0));
    bool hasBlueLine() => tester
        .widgetList<PolylineLayer>(find.byType(PolylineLayer))
        .any(
          (layer) => layer.polylines.any((line) => line.color == Colors.blue),
        );
    expect(hasBlueLine(), isTrue);
    debugPrint(
      'MVP_SEARCH_ROUTE distance=${controller.route!.distanceMeters} '
      'elapsedMs=${controller.calculationMilliseconds}',
    );

    final validOrigin = controller.origin;
    controller.chooseOnMap(Selection.origin);
    controller.mapPoint(const Coordinate(lat: 19.55, lon: -71.73));
    expect(controller.origin, same(validOrigin));
    expect(controller.message, isNotEmpty);
    controller.cancelSelection();
    await tester.ensureVisible(find.text('Limpiar'));
    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(controller.origin, isNull);
    expect(controller.destination, isNull);
    expect(controller.route, isNull);
    expect(controller.query, isEmpty);
    expect(hasBlueLine(), isFalse);
    // Recovery after rejected outside point and clear, using the same screen.
    controller.chooseOnMap(Selection.origin);
    controller.mapPoint(const Coordinate(lat: 19.4517, lon: -70.697));
    expect(controller.origin, isNotNull);
    // Real disconnected OSM component, found in the national graph acceptance
    // test. The UI must recover when the user corrects the destination.
    controller.chooseOnMap(Selection.destination);
    controller.mapPoint(const Coordinate(lat: 19.4009853, lon: -70.6321272));
    Future<void> waitForRoute() async {
      await tester.pump();
      await tester.runAsync(() async {
        final watch = Stopwatch()..start();
        while (controller.calculating && watch.elapsed.inSeconds < 60) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pumpAndSettle();
    }

    await waitForRoute();
    expect(controller.route, isNull);
    expect(controller.routeFailure, RouteFailure.disconnected);
    expect(
      find.text('No hay conexión peatonal entre estos puntos.'),
      findsWidgets,
    );
    expect(hasBlueLine(), isFalse);
    controller.chooseOnMap(Selection.destination);
    controller.mapPoint(const Coordinate(lat: 19.793, lon: -70.688));
    await waitForRoute();
    expect(controller.route, isNotNull, reason: controller.message);
    expect(controller.routeFailure, isNull);
    expect(hasBlueLine(), isTrue);
    expect(gps.calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
