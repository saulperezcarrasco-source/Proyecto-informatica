import 'dart:convert';
import 'dart:ui' show FrameTiming;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';
import 'package:ruta_rd/features/navigation/navigation_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('GNSS nativo offline: espera, posicion y avance sin proveedor fused', (
    tester,
  ) async {
    final home = HomeController();
    await home.retry();
    final places = home.region!.places;
    home.select(
      places.firstWhere((p) => p.name == 'Café Conde de Peñalba'),
      Selection.origin,
    );
    home.select(
      places.firstWhere((p) => p.name == 'Café La Moricette'),
      Selection.destination,
    );
    await home.calculate();
    final route = home.route!;
    final nav = NavigationController(
      route: route,
      destination: home.destination!.coordinate,
      origin: home.origin!.coordinate,
      location: GpsLocationService(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NavigationScreen(home: home, navigation: nav),
      ),
    );
    await tester.pump();
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> values) => timings.addAll(values);
    tester.binding.addTimingsCallback(collect);
    addTearDown(() => tester.binding.removeTimingsCallback(collect));
    Map<String, double> point(Coordinate p) => {'lat': p.lat, 'lon': p.lon};
    debugPrint(
      'GNSS_READY ${jsonEncode({'start': point(home.origin!.coordinate), 'middle': point(route.coordinates[route.coordinates.length ~/ 2]), 'end': point(home.destination!.coordinate), 'path': nav.progress.points.map(point).toList()})}',
    );
    Future<void> waitFor(bool Function() condition) async {
      await tester.runAsync(() async {
        final timer = Stopwatch()..start();
        while (!condition() && nav.active && timer.elapsed.inSeconds < 70) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      });
      await tester.pump(const Duration(milliseconds: 600));
      expect(nav.active, isTrue, reason: nav.status);
      expect(condition(), isTrue, reason: nav.status);
    }

    await waitFor(() => nav.position != null);
    final first = nav.remainingMeters;
    timings.clear();
    debugPrint('GNSS_FIRST distance=$first accuracy=${nav.accuracy}');
    await waitFor(() => nav.remainingMeters < first - 20);
    debugPrint('GNSS_PROGRESS distance=${nav.remainingMeters}');
    await waitFor(() => nav.arrived);
    expect(nav.remainingMeters, 0);
    expect(nav.route, same(route));
    expect(tester.takeException(), isNull);
    debugPrint(
      'GNSS_OFFLINE_PASS first=$first final=${nav.remainingMeters} accuracy=${nav.accuracy}',
    );
    if (timings.isNotEmpty) {
      final builds =
          timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      final rasters =
          timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      debugPrint(
        'GNSS_FRAMES frames=${timings.length} buildP90=${builds[(builds.length * .9).floor()]} rasterP90=${rasters[(rasters.length * .9).floor()]}',
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 12)),
    );
    await tester.pumpWidget(const SizedBox());
    nav.dispose();
    home.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
