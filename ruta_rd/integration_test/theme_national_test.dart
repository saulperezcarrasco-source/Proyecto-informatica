import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_rd/main.dart';
import 'package:ruta_rd/core/theme_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('tema persistente y mapa nacional con archivo local', (
    tester,
  ) async {
    await tester.pumpWidget(const RutaRdApp());
    for (
      var i = 0;
      i < 150 && find.byType(vt.VectorTileLayer).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(vt.VectorTileLayer), findsOneWidget);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(FlutterMap));
    final prefs = ThemePreferencesScope.of(context)!;
    if (Theme.of(context).brightness != Brightness.dark) {
      await tester.ensureVisible(find.byTooltip('Activar modo oscuro'));
      await tester.tap(find.byTooltip('Activar modo oscuro'));
      await tester.pumpAndSettle();
    }
    expect(
      Theme.of(tester.element(find.byType(FlutterMap))).brightness,
      Brightness.dark,
    );
    final reopened = ThemePreferences();
    await reopened.load();
    expect(reopened.mode, ThemeMode.dark);
    reopened.dispose();
    final layer = tester.widget<vt.VectorTileLayer>(
      find.byType(vt.VectorTileLayer),
    );
    expect(layer.tileProviders.providers.keys, ['protomaps']);
    final source = layer.tileProviders.providers['protomaps']!;
    expect(source, isA<vt.PmTilesVectorTileProvider>());
    await tester.ensureVisible(find.text('Ver toda RD'));
    await tester.tap(find.text('Ver toda RD'));
    await tester.pumpAndSettle();
    final map = MapController.of(
      tester.element(find.byType(vt.VectorTileLayer)),
    );
    expect(map.camera.zoom, lessThan(9));
    // Visit uncached parts of the archive while the emulator is offline.
    for (final point in [
      const LatLng(19.4517, -70.697),
      const LatLng(18.582, -68.405),
      const LatLng(18.2085, -71.1008),
    ]) {
      map.move(point, 13);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    // Test the day palette too, then leave the app in night mode.
    await prefs.toggle(Brightness.dark);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(FlutterMap))).brightness,
      Brightness.light,
    );
    await prefs.toggle(Brightness.light);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(FlutterMap))).brightness,
      Brightness.dark,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
