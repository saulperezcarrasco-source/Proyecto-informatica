import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/features/favorites/favorite_repository.dart';
import 'package:ruta_rd/features/favorites/favorites_controller.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'favoritos offline: guardar dos, reabrir, elegir A/B, quitar sin alterar ruta',
    (tester) async {
      final repository = LocalFavoriteRepository();
      await repository.save([]);
      var favorites = FavoritesController();
      var home = HomeController();
      await home.retry();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: home, favoritesController: favorites),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('origin-search'));
      // This fixture verifies favorites; native IME input is checked separately
      // against the normal release through adb/uiautomator.
      tester.widget<TextField>(search).onChanged!('cafe');
      await tester.pumpAndSettle();
      expect(home.results.length, greaterThanOrEqualTo(2));
      for (var i = 0; i < 2; i++) {
        debugPrint(
          'FAVORITES_SAVE $i results=${home.results.length} saved=${favorites.entries.length} buttons=${find.byTooltip('Guardar en favoritos').evaluate().length}',
        );
        final save = find.byTooltip('Guardar en favoritos').first;
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
      }
      expect(favorites.entries, hasLength(2));
      expect(home.origin, isNull);
      expect(home.route, isNull);
      final ids = favorites.entries.map((entry) => entry.placeId).toList();
      expect(
        favorites.entries.every(
          (entry) =>
              entry.regionId == home.region!.manifest.id &&
              entry.regionVersion == home.region!.manifest.version,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      favorites.dispose();
      home.dispose();
      // New controllers and a new screen must read native persisted preferences.
      favorites = FavoritesController();
      home = HomeController();
      await home.retry();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: home, favoritesController: favorites),
        ),
      );
      await tester.pumpAndSettle();
      expect(favorites.entries.map((entry) => entry.placeId), ids);
      for (var i = 0; i < 2; i++) {
        final panel = find.byKey(const ValueKey('favorites-panel-toggle'));
        await tester.ensureVisible(panel);
        await tester.tap(panel);
        await tester.pumpAndSettle();
        final row = find.byKey(
          ValueKey('favorite-${home.region!.manifest.id}-${ids[i]}'),
        );
        final action = find.descendant(
          of: row,
          matching: find.text(
            i == 0 ? 'Usar como origen' : 'Usar como destino',
          ),
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(home.origin!.id, ids[0]);
      expect(home.destination!.id, ids[1]);
      expect(home.route, isNotNull, reason: home.message);
      final route = home.route;
      await tester.ensureVisible(
        find.byKey(const ValueKey('favorites-panel-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('favorites-panel-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar de favoritos').first);
      await tester.pumpAndSettle();
      expect(favorites.entries, hasLength(1));
      expect(home.route, same(route));
      expect(home.origin!.id, ids[0]);
      expect((await LocalFavoriteRepository().load()).single.placeId, ids[1]);
      Navigator.of(tester.element(find.text('Favoritos').last)).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      debugPrint(
        'FAVORITES_ANDROID saved=2 reopened=2 removed=1 remaining=1 '
        'region=${home.region!.manifest.id} version=${home.region!.manifest.version} '
        'routeMeters=${route!.distanceMeters}; offline storage',
      );
      await tester.pumpWidget(const SizedBox());
      favorites.dispose();
      home.dispose();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
