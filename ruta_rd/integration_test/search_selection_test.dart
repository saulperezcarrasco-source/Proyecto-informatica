import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/map/local_map.dart';

class NoGps extends LocationService {
  int calls = 0;
  @override
  Future<LocationReading> getCurrentLocation() async {
    calls++;
    throw StateError('No se debe solicitar GPS');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('buscar elegir limpiar y seleccionar mapa sin GPS', (
    tester,
  ) async {
    final gps = NoGps();
    final c = HomeController(location: gps);
    await c.retry();
    expect(c.state, RegionState.ready);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(controller: c)));
    await tester.pumpAndSettle();
    var search = find.byKey(const ValueKey('origin-search'));
    await tester.enterText(search, '  CAFE  ');
    await tester.pumpAndSettle();
    expect(c.results, isNotEmpty);
    expect(c.results.length, lessThanOrEqualTo(10));
    await tester.tap(find.text('Usar como origen').first);
    await tester.pumpAndSettle();
    expect(c.origin, isNotNull);
    expect(c.query, isEmpty);
    search = find.byKey(const ValueKey('destination-search'));
    await tester.ensureVisible(search);
    await tester.tap(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'café');
    await tester.pumpAndSettle();
    expect(
      c.query,
      'café',
      reason: 'El campo debe conservar la segunda consulta',
    );
    expect(
      c.results,
      isNotEmpty,
      reason: 'La búsqueda con tilde debe devolver resultados',
    );
    await tester.tap(find.text('Usar como destino').first);
    await tester.pumpAndSettle();
    expect(c.destination, isNotNull);
    await tester.ensureVisible(search);
    await tester.tap(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'zzsincoincidencias');
    await tester.pumpAndSettle();
    expect(find.text('No se encontraron lugares.'), findsOneWidget);
    await tester.tap(find.byTooltip('Borrar destino'));
    await tester.pumpAndSettle();
    expect(c.results, isEmpty);
    await tester.ensureVisible(find.text('Limpiar'));
    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(c.origin, isNull);
    for (final label in ['Elegir origen en mapa', 'Elegir destino en mapa']) {
      await tester.ensureVisible(find.byTooltip(label));
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(
        c.selection,
        label.contains('origen') ? Selection.origin : Selection.destination,
      );
      await tester.ensureVisible(find.byType(LocalMap));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(LocalMap)));
      // flutter_map waits briefly to distinguish a tap from double-tap zoom.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        c.selection,
        isNull,
        reason: 'El toque debe completar la selección: ${c.message}',
      );
    }
    expect(c.origin, isNotNull);
    expect(c.destination, isNotNull);
    final origin = c.origin;
    c.chooseOnMap(Selection.origin);
    c.mapPoint(const Coordinate(lat: 0, lon: 0));
    expect(c.origin, origin);
    c.cancelSelection();
    expect(gps.calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
