import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/data/region_repository.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';
import 'package:ruta_rd/core/brand_logo.dart';

class SlowRepository extends RegionRepository {
  final result = Completer<RegionData>();
  @override
  Future<RegionData> loadRegion() => result.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'logo de inicio tiene estilo Material y cede al mapa tras el primer frame',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrandLaunch(child: Scaffold(body: Text('Mapa listo'))),
        ),
      );
      final rich = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText() == 'Preparando tu mapa sin conexión…',
        ),
      );
      expect(rich.text.style!.fontSize, lessThan(24));
      expect(
        rich.text.style!.decoration ?? TextDecoration.none,
        TextDecoration.none,
      );
      expect(find.byType(BrandLogo), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('arranque identificado, espera acotada y reintento accesible', (
    tester,
  ) async {
    final repository = SlowRepository();
    final controller = HomeController(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Preparando tu mapa sin conexión…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudieron cargar los datos locales.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.text('Preparando tu mapa sin conexión…'), findsOneWidget);
    repository.result.completeError(const FormatException('Fixture inválido'));
    await tester.pumpAndSettle();
    expect(controller.state, RegionState.error);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
