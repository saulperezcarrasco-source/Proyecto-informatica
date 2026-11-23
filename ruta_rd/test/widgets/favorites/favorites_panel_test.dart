import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/data/region_repository.dart';
import 'package:ruta_rd/features/favorites/favorite_repository.dart';
import 'package:ruta_rd/features/favorites/favorites_controller.dart';
import 'package:ruta_rd/features/favorites/favorites_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'un lugar eliminado no se puede elegir y puede quitarse con texto al 200 %',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final region = await RegionRepository().loadRegion();
      final controller = FavoritesController();
      await controller.load();
      await controller.toggle(
        Favorite(
          placeId: 'eliminado',
          regionId: region.manifest.id,
          regionVersion: 'anterior',
        ),
      );
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: FavoritesPanel(
                  controller: controller,
                  region: region.manifest,
                  places: region.places,
                  onOrigin: (_) => selections++,
                  onDestination: (_) => selections++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('favorites-panel-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Lugar no disponible'), findsOneWidget);
      expect(find.text('Usar como origen'), findsNothing);
      await tester.tap(find.byTooltip('Quitar de favoritos'));
      await tester.pumpAndSettle();
      expect(controller.entries, isEmpty);
      expect(selections, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'datos corruptos muestran recuperación y cancelar no destruye favoritos',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        LocalFavoriteRepository.storageKey: 'invalid',
      });
      final region = await RegionRepository().loadRegion();
      final controller = FavoritesController();
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FavoritesPanel(
              controller: controller,
              region: region.manifest,
              places: region.places,
              onOrigin: (_) {},
              onDestination: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Restablecer favoritos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(controller.ready, isFalse);
      await tester.tap(find.text('Restablecer favoritos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restablecer'));
      await tester.pumpAndSettle();
      expect(controller.ready, isTrue);
      expect(controller.error, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
