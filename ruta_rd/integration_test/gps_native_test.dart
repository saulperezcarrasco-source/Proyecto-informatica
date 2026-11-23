import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';
import 'package:ruta_rd/features/location/location_service.dart';

// Host setup supplies native Android permissions, location mode and emulator
// geo fix. There is no fake GpsPlatform or LocationService in this test.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const scenario = String.fromEnvironment(
    'GPS_EXPECTATION',
    defaultValue: 'success',
  );
  testWidgets('GPS Android nativo: $scenario y selección manual operativa', (
    tester,
  ) async {
    final controller = HomeController();
    await controller.retry();
    expect(controller.state, RegionState.ready);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    final places = controller.region!.places;
    final origin = places.firstWhere((p) => p.name == 'Café Conde de Peñalba');
    final destination = places.firstWhere(
      (p) => p.name == 'Cafeteria Sabor Real',
    );
    controller.select(origin, Selection.origin);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Mi ubicación'));
    await tester.tap(find.byTooltip('Mi ubicación'));
    await tester.pump();
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      while (controller.locating && watch.elapsed.inSeconds < 25) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    expect(controller.locating, isFalse);
    switch (scenario) {
      case 'success':
        expect(
          controller.locationFailure,
          isNull,
          reason: controller.locationMessage,
        );
        expect(controller.origin!.id, 'gps');
        expect(controller.origin!.coordinate.lat, closeTo(18.4737, .002));
        expect(controller.origin!.coordinate.lon, closeTo(-69.8844, .002));
        expect(controller.accuracy, greaterThanOrEqualTo(0));
        debugPrint(
          'NATIVE_GPS success accuracy=${controller.accuracy} '
          'approximate=${controller.approximateLocation}; emulator injected position',
        );
      case 'denied':
        expect(
          controller.locationFailure,
          anyOf(
            LocationFailure.permissionDenied,
            LocationFailure.permissionDeniedForever,
          ),
        );
        expect(controller.origin, same(origin));
      case 'disabled':
        expect(controller.locationFailure, LocationFailure.serviceDisabled);
        expect(controller.origin, same(origin));
      default:
        fail('GPS_EXPECTATION desconocido: $scenario');
    }
    // A native failure must not prevent selecting points or calculating routes.
    controller.selectAndRoute(origin, Selection.origin);
    controller.selectAndRoute(destination, Selection.destination);
    await tester.pumpAndSettle();
    expect(controller.route, isNotNull, reason: controller.message);
    expect(controller.route!.distanceMeters, greaterThan(0));
    debugPrint(
      'NATIVE_GPS $scenario manualRoute=${controller.route!.distanceMeters}',
    );
    await tester.ensureVisible(find.text('Limpiar'));
    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(controller.origin, isNull);
    expect(controller.route, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
