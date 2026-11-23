import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('rutas locales, resumen, cambio de destino y limpieza', (
    tester,
  ) async {
    final controller = HomeController();
    await controller.retry();
    expect(controller.state, RegionState.ready);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    final samples = <Map<String, Object>>[];
    final places = controller.region!.places;
    final names = [
      'Café Conde de Peñalba',
      'Café La Moricette',
      'Cafeteria Sabor Real',
    ];
    final selected = names
        .map((name) => places.firstWhere((p) => p.name == name))
        .toList();
    for (var i = 0; i < 3; i++) {
      controller.select(selected[i], Selection.origin);
      controller.select(selected[(i + 1) % 3], Selection.destination);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Calcular ruta'));
      await tester.tap(find.text('Calcular ruta'));
      await tester.pumpAndSettle();
      final result = controller.route;
      expect(result, isNotNull, reason: controller.message);
      // Check every plotted segment is an actual directed edge of the source graph.
      final nodes = controller.region!.graph.nodes;
      String id(Coordinate c) => nodes.firstWhere((n) => n.coordinate == c).id;
      var total = 0.0;
      for (var j = 1; j < result!.coordinates.length; j++) {
        final edge = controller.region!.graph.edges.firstWhere(
          (e) =>
              e.from == id(result.coordinates[j - 1]) &&
              e.to == id(result.coordinates[j]),
        );
        total += edge.distanceMeters;
      }
      expect(total, closeTo(result.distanceMeters, .001));
      expect(controller.calculationMilliseconds, lessThan(1000));
      await tester.ensureVisible(find.byKey(const ValueKey('route-summary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Detalles de ruta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('accesos no verificados'), findsOneWidget);
      samples.add({
        'from': selected[i].name,
        'to': selected[(i + 1) % 3].name,
        'distanceMeters': result.distanceMeters,
        'durationMs': controller.calculationMilliseconds!,
      });
      await tester.ensureVisible(find.text('Borrar ruta'));
      await tester.tap(find.text('Borrar ruta'));
      await tester.pumpAndSettle();
      expect(controller.route, isNull);
      expect(controller.origin, isNotNull);
    }
    // Two distinct real places that snap to the same graph node.
    controller.select(
      places.firstWhere((p) => p.name == 'Café La Moricette'),
      Selection.origin,
    );
    controller.select(
      places.firstWhere((p) => p.name == 'Café Santo Domingo'),
      Selection.destination,
    );
    await controller.calculate();
    await tester.pumpAndSettle();
    expect(controller.route!.distanceMeters, 0);
    expect(controller.route!.destinationApproachMeters, greaterThan(0));
    await tester.ensureVisible(find.byTooltip('Detalles de ruta'));
    await tester.tap(find.byTooltip('Detalles de ruta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mismo nodo'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    // Exercise a real disconnected component and then recover with a valid pair.
    final graph = controller.region!.graph;
    final start = graph.nodes.first;
    GraphNode? unreachable;
    for (final node in graph.nodes) {
      try {
        controller.router!.calculateRoute(start.coordinate, node.coordinate);
      } on RouteFailure catch (e) {
        if (e == RouteFailure.disconnected) {
          unreachable = node;
          break;
        }
      }
    }
    expect(unreachable, isNotNull);
    Place point(GraphNode n) => Place(
      id: n.id,
      name: 'Punto de prueba',
      category: 'test',
      coordinate: n.coordinate,
    );
    controller.select(point(start), Selection.origin);
    controller.select(point(unreachable!), Selection.destination);
    await controller.calculate();
    await tester.pumpAndSettle();
    expect(controller.routeFailure, RouteFailure.disconnected);
    controller.select(selected.first, Selection.origin);
    controller.select(selected[1], Selection.destination);
    await controller.calculate();
    await tester.pumpAndSettle();
    expect(controller.route, isNotNull);
    controller.select(selected[2], Selection.destination);
    await tester.pumpAndSettle();
    expect(controller.route, isNull);
    await tester.ensureVisible(find.text('Limpiar'));
    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(controller.origin, isNull);
    expect(controller.destination, isNull);
    // Output captured by the test runner for the evidence report.
    debugPrint('ROUTING_MEASUREMENTS ${jsonEncode(samples)}');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
