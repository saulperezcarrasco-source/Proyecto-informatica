import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruta_rd/data/region_repository.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';
import 'package:ruta_rd/features/navigation/navigation_screen.dart';

import 'navigation_test.dart' show MovingGps, a, c, route;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'cámara sigue pasos de un metro sin esperar acumular dos metros',
    (tester) async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      );
      final home = HomeController()
        ..region = await RegionRepository().loadRegion();
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationScreen(home: home, navigation: nav),
        ),
      );
      gps.fixes.add(const LocationReading(a, 5));
      await tester.pumpAndSettle();
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final start = map.camera.center;
      final step = Coordinate(lat: a.lat + .00001, lon: a.lon);
      gps.fixes.add(LocationReading(step, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 180));
      expect(map.camera.center.latitude, greaterThan(start.latitude + .000008));
      expect(map.camera.center.latitude, closeTo(step.lat, .000002));
      nav.setFollow(false);
      final paused = map.camera.center;
      gps.fixes.add(
        LocationReading(Coordinate(lat: a.lat + .00002, lon: a.lon), 5),
      );
      await tester.pumpAndSettle();
      expect(map.camera.center, paused);
      nav.setFollow(true);
      await tester.pumpAndSettle();
      expect(map.camera.center.latitude, closeTo(a.lat + .00002, .000002));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      nav.dispose();
      home.dispose();
      await gps.fixes.close();
    },
  );
  testWidgets(
    'espera satelital larga, recuperación al volver y pausa manual conservada',
    (tester) async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      );
      final home = HomeController()
        ..region = await RegionRepository().loadRegion();
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationScreen(home: home, navigation: nav),
        ),
      );
      await tester.pump(const Duration(seconds: 35));
      expect(nav.active, isTrue);
      expect(nav.status, contains('Buscando satélites'));
      final observer =
          tester.state(find.byType(NavigationScreen)) as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(nav.active, isFalse);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(nav.active, isTrue);
      gps.fixes.add(const LocationReading(a, 5));
      await tester.pumpAndSettle();
      expect(nav.position, isNotNull);
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(nav.active, isFalse);
      nav.start();
      gps.fixes.addError(
        const LocationException(LocationFailure.precisePermissionRequired),
      );
      await tester.pumpAndSettle();
      expect(find.text('Permisos de ubicación'), findsOneWidget);
      expect(nav.active, isFalse);
      await tester.pumpWidget(const SizedBox());
      nav.dispose();
      home.dispose();
      await gps.fixes.close();
    },
  );
}
