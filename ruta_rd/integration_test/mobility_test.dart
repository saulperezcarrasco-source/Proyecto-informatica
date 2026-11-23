import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/main.dart';
import 'package:ruta_rd/core/brand_logo.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/core/travel_mode.dart';
import 'package:ruta_rd/core/route_instructions.dart';
import 'package:ruta_rd/features/map/local_map.dart';
import 'package:ruta_rd/features/map/route_endpoint.dart';
import 'package:ruta_rd/features/home/home_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('logo, cuatro transportes, tiempos, A/B y lugares adicionales', (
    tester,
  ) async {
    await tester.pumpWidget(const RutaRdApp());
    expect(find.byType(BrandLogo), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    await tester.pumpAndSettle();
    final home = tester.widget<LocalMap>(find.byType(LocalMap)).controller;
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      while (!home.nationalSearchReady && watch.elapsed.inSeconds < 40) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    expect(home.nationalSearchReady, isTrue, reason: home.searchNotice);
    expect(home.places.length, greaterThan(95308));
    expect(find.text(routeInstructions), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    final extra = await tester.runAsync(
      () => home.nationalSearch!.search('Colmado sin nombre Santiago'),
    );
    expect(extra, isNotEmpty);
    expect(extra!.every((p) => p.name.contains('(sin nombre)')), isTrue);
    const start = Place(
      id: 'test-santiago',
      name: 'Santiago',
      category: 'lugar',
      coordinate: Coordinate(lat: 19.4517, lon: -70.697),
    );
    const end = Place(
      id: 'test-puerto-plata',
      name: 'Puerto Plata',
      category: 'lugar',
      coordinate: Coordinate(lat: 19.793, lon: -70.688),
    );
    home.selectAndRoute(start, Selection.origin);
    home.selectAndRoute(end, Selection.destination);
    Future<void> waitRoute() async {
      await tester.pump();
      await tester.runAsync(() async {
        final watch = Stopwatch()..start();
        while ((home.calculating || home.route == null) &&
            home.routeFailure == null &&
            watch.elapsed.inSeconds < 60) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pumpAndSettle();
      expect(
        home.route,
        isNotNull,
        reason: '${home.message} ${home.islandRouting.diagnostic}',
      );
    }

    final state = tester.state(find.byType(LocalMap));
    final durations = <TravelMode, double>{};
    for (final mode in TravelMode.values) {
      final chip = find.byKey(ValueKey('travel-${mode.assetName}'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await waitRoute();
      expect(home.route!.mode, mode);
      expect(home.origin, same(start));
      expect(home.destination, same(end));
      expect(tester.state(find.byType(LocalMap)), same(state));
      expect(find.byType(RouteEndpoint), findsWidgets);
      durations[mode] = home.route!.estimatedMinutes;
      debugPrint(
        'MOBILITY_ROUTE ${mode.name}: ${home.route!.distanceMeters} m, ${home.route!.estimatedMinutes} min, ${home.route!.coordinates.length} vertices, calcMs=${home.calculationMilliseconds}',
      );
    }
    expect(
      durations[TravelMode.walking]!,
      greaterThan(durations[TravelMode.bicycle]!),
    );
    expect(
      durations[TravelMode.bicycle]!,
      greaterThan(durations[TravelMode.car]!),
    );
    expect(durations.values.toSet().length, 4);
    home.setTravelMode(TravelMode.walking);
    await waitRoute();
    expect(tester.takeException(), isNull);
    debugPrint(
      'MOBILITY_UI PASS catalog=${home.places.length}; original PNG splash; four modes; unnamed OSM; no map recreation',
    );
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 6)));
}
