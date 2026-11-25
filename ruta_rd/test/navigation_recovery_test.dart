import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruta_rd/data/region_repository.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';
import 'package:ruta_rd/features/navigation/navigation_screen.dart';

import 'navigation_test.dart' show MovingGps, a, c, route;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
