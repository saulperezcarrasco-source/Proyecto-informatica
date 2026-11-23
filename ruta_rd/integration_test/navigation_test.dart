import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart' show kProfileMode;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';
import 'package:ruta_rd/features/navigation/navigation_screen.dart';
import 'package:ruta_rd/features/search/national_search.dart';
import 'package:ruta_rd/features/map/national_places_layer.dart';

// Movement is deliberately injected at the service boundary, not presented as
// physical GPS. The final release APK is also checked with Android emu geo fix.
class ScriptedGps extends LocationService {
  final fixes = StreamController<LocationReading>.broadcast(sync: true);
  @override
  Future<LocationReading> getCurrentLocation() => throw UnimplementedError();
  @override
  Stream<LocationReading> watch() => fixes.stream;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('RD nacional, navegación con movimiento y zoom/pan sin perder estado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final gps = ScriptedGps();
      final home = HomeController(
        location: gps,
        nationalSearch: NationalSearch(),
      );
      await home.retry();
      await tester.runAsync(() async {
        final watch = Stopwatch()..start();
        while (!home.nationalSearchReady && watch.elapsed.inSeconds < 30) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      expect(home.nationalSearchReady, isTrue, reason: home.searchNotice);
      expect(home.places.length, greaterThan(95308));
      await tester.pumpWidget(MaterialApp(home: HomeScreen(controller: home)));
      await tester.pumpAndSettle();
      if (kProfileMode) {
        // AOT performance harness checks the real catalogue directly; native
        // keyboard/search interaction is covered by the debug UI and release QA.
        final matches = await tester.runAsync(
          () => home.nationalSearch!.search('Puerto Plata'),
        );
        expect(matches, isNotEmpty);
      } else {
        await tester.enterText(
          find.byKey(const ValueKey('origin-search')),
          'Puerto Plata',
        );
        // Advance the test clock past the debounce even if the AOT map has no
        // pending animation frames for pumpAndSettle to advance it implicitly.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await tester.pumpAndSettle();
        expect(home.results, isNotEmpty);
        expect(home.results.any((p) => p.id.startsWith('rd:')), isTrue);
      }
      home.search('');
      final monuments = await tester.runAsync(
        () => home.nationalSearch!.search('monumento de santiago'),
      );
      expect(monuments!.first.id, 'rd:way:191967205');
      home.selectAndRoute(monuments.first, Selection.origin);
      await tester.pumpAndSettle();
      final layer = tester.widget<NationalPlacesLayer>(
        find.byType(NationalPlacesLayer),
      );
      expect(
        layer.hits.labels.any((h) => h.$2.id == monuments.first.id),
        isTrue,
      );
      final other = layer.hits.labels
          .where((h) => h.$2.id != monuments.first.id)
          .first;
      final box = tester.renderObject<RenderBox>(
        find.byType(NationalPlacesLayer),
      );
      home.chooseOnMap(Selection.destination);
      await tester.pump();
      await tester.tapAt(box.localToGlobal(other.$1.center));
      await tester.pump();
      expect(home.destination!.id, other.$2.id);
      expect(find.textContaining('Tiempo estimado a'), findsNothing);
      expect(find.textContaining('revisión final'), findsNothing);
      debugPrint(
        'NATIONAL_LABELS monumentFound=true painted=${layer.hits.labels.length} selectedPoi=${other.$2.name}',
      );
      home.clear();
      final places = home.region!.places;
      home.selectAndRoute(
        places.firstWhere((p) => p.name == 'Café Conde de Peñalba'),
        Selection.origin,
      );
      home.selectAndRoute(
        places.firstWhere((p) => p.name == 'Cafeteria Sabor Real'),
        Selection.destination,
      );
      await tester.pumpAndSettle();
      final route = home.route!;
      final nav = NavigationController(
        route: route,
        destination: home.destination!.coordinate,
        location: gps,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationScreen(home: home, navigation: nav),
        ),
      );
      await tester.pumpAndSettle();
      gps.fixes.add(LocationReading(route.coordinates.first, 5));
      await tester.pumpAndSettle();
      final first = nav.remainingMeters;
      gps.fixes.add(
        LocationReading(route.coordinates[route.coordinates.length ~/ 2], 5),
      );
      await tester.pumpAndSettle();
      expect(nav.remainingMeters, lessThan(first - 20));
      expect(home.route, same(route));
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      debugPrint(
        'NAVIGATION_CAMERA center=${camera.center} zoom=${camera.zoom} follow=${nav.follow} arrowWidgets=${find.byKey(const ValueKey('navigation-position')).evaluate().length}',
      );
      expect(find.byKey(const ValueKey('navigation-position')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Tu posición actual')),
        findsOneWidget,
      );
      final movingPosition = nav.position;
      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();
      gps.fixes.add(LocationReading(route.coordinates.last, 5));
      await tester.pump();
      expect(nav.position, same(movingPosition));
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      // Let the real scheduler draw continuously; pump(Duration) throttles the
      // test binding and must not be counted as application build work.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      final timings = <FrameTiming>[];
      void collect(List<FrameTiming> values) => timings.addAll(values);
      final policy = binding.framePolicy;
      binding.framePolicy =
          LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
      binding.addTimingsCallback(collect);
      try {
        await tester.runAsync(() async {
          for (var i = 0; i < 120; i++) {
            final zoomPhase = i < 60 ? i / 60 : (120 - i) / 60;
            map.move(
              LatLng(18.4735 + (i % 20) * .00002, -69.8855 + (i % 15) * .00002),
              15.5 + zoomPhase * 1.75,
            );
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        });
      } finally {
        binding.removeTimingsCallback(collect);
        binding.framePolicy = policy;
      }
      await tester.pumpAndSettle();
      if (timings.isNotEmpty) {
        final raster =
            timings.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
              ..sort();
        final builds =
            timings.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
              ..sort();
        final build = builds.reduce((a, b) => a + b) / builds.length;
        debugPrint(
          'NAVIGATION_PERF mode=${kProfileMode ? 'profile' : 'debug'} buildAvgMs=$build buildP90Ms=${builds[(builds.length * .9).floor()]} buildOver16=${builds.where((v) => v > 16.67).length} rasterAvgMs=${raster.reduce((a, b) => a + b) / raster.length} rasterP90Ms=${raster[(raster.length * .9).floor().clamp(0, raster.length - 1)]} frames=${timings.length}; continuous scheduler; injected positions',
        );
      }
      expect(home.route, same(route));
      expect(tester.takeException(), isNull);
      gps.fixes.add(LocationReading(home.destination!.coordinate, 5));
      await tester.pumpAndSettle();
      expect(nav.arrived, isTrue);
      expect(find.text('Has llegado'), findsOneWidget);
      debugPrint(
        'NAVIGATION_TEST mode=${kProfileMode ? 'profile' : 'debug'} catalog=${home.places.length} before=$first after=${nav.remainingMeters}; injected movement; panZoom=120; originalRoutePreserved=true',
      );
      await tester.pumpWidget(const SizedBox());
      nav.dispose();
      home.dispose();
      await gps.fixes.close();
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
