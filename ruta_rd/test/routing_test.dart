import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/data/region_repository.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/routing/routing_service.dart';

const a = Coordinate(lat: 18.474, lon: -69.885),
    b = Coordinate(lat: 18.4741, lon: -69.885),
    c = Coordinate(lat: 18.4742, lon: -69.885),
    d = Coordinate(lat: 18.477, lon: -69.881);
const nodes = [
  GraphNode(id: 'a', coordinate: a),
  GraphNode(id: 'b', coordinate: b),
  GraphNode(id: 'c', coordinate: c),
  GraphNode(id: 'd', coordinate: d),
];
const edges = [
  GraphEdge(from: 'a', to: 'b', distanceMeters: 4),
  GraphEdge(from: 'b', to: 'c', distanceMeters: 5),
  GraphEdge(from: 'a', to: 'c', distanceMeters: 20),
];
Place place(Coordinate p) =>
    Place(id: 'test', name: 'Punto', category: 'test', coordinate: p);

void main() {
  test(
    'traza automáticamente al elegir B y al cambiar cualquiera de los puntos',
    () async {
      final controller = HomeController()
        ..router = RoutingService(
          const RoutingGraph(nodes: nodes, edges: edges),
        );
      addTearDown(controller.dispose);
      Future<void> selected(Coordinate point, Selection target) async {
        final done = Completer<void>();
        final previous = controller.route;
        void listener() {
          if (controller.route != null &&
              !identical(controller.route, previous) &&
              !done.isCompleted) {
            done.complete();
          }
        }

        controller.addListener(listener);
        controller.chooseOnMap(target);
        controller.mapPoint(point);
        try {
          await done.future.timeout(const Duration(seconds: 2));
        } finally {
          controller.removeListener(listener);
        }
      }

      controller.chooseOnMap(Selection.origin);
      controller.mapPoint(a);
      expect(controller.origin, isNotNull);
      expect(controller.route, isNull);
      await selected(c, Selection.destination);
      expect(controller.route!.distanceMeters, 9);
      await selected(b, Selection.destination);
      expect(controller.route!.distanceMeters, 4);
      await selected(b, Selection.origin);
      expect(controller.route!.distanceMeters, 0);
      controller.chooseOnMap(Selection.destination);
      controller.mapPoint(c);
      controller.clear();
      await Future<void>.delayed(Duration.zero);
      expect(controller.route, isNull);
      expect(controller.calculating, isFalse);
    },
  );
  test('menor distancia reconstruida, dirección y desconexión', () {
    final service = RoutingService(
      const RoutingGraph(nodes: nodes, edges: edges),
    );
    final result = service.calculateRoute(a, c);
    expect(result.coordinates, [a, b, c]);
    expect(result.distanceMeters, 9);
    expect(result.estimatedMinutes, 9 / 75);
    expect(
      () => service.calculateRoute(c, a),
      throwsA(RouteFailure.disconnected),
    );
    expect(
      () => service.calculateRoute(a, d),
      throwsA(RouteFailure.disconnected),
    );
  });
  test('pesos, referencias, nodos y configuración inválidos', () {
    for (final weight in [-1.0, 0.0, double.nan, double.infinity]) {
      expect(
        () => RoutingService(
          RoutingGraph(
            nodes: nodes,
            edges: [GraphEdge(from: 'a', to: 'b', distanceMeters: weight)],
          ),
        ),
        throwsA(RouteFailure.invalidData),
      );
    }
    expect(
      () => RoutingService(
        const RoutingGraph(
          nodes: nodes,
          edges: [GraphEdge(from: 'a', to: 'x', distanceMeters: 1)],
        ),
      ),
      throwsA(RouteFailure.invalidData),
    );
    expect(
      () => RoutingService(const RoutingGraph(nodes: [], edges: [])),
      throwsA(RouteFailure.invalidData),
    );
    expect(
      () => RoutingService(
        const RoutingGraph(
          nodes: [GraphNode(id: 'x', coordinate: Coordinate(lat: 91, lon: 0))],
          edges: [],
        ),
      ),
      throwsA(RouteFailure.invalidData),
    );
    expect(
      () => RoutingService(
        const RoutingGraph(
          nodes: [
            GraphNode(id: 'a', coordinate: a),
            GraphNode(id: 'a', coordinate: b),
          ],
          edges: [],
        ),
      ),
      throwsA(RouteFailure.invalidData),
    );
    expect(
      () => RoutingService(
        const RoutingGraph(nodes: nodes, edges: edges),
        maxApproach: 0,
      ),
      throwsA(RouteFailure.invalidData),
    );
  });
  test('origen igual, mismo nodo y aproximaciones separadas', () {
    final service = RoutingService(
      const RoutingGraph(nodes: nodes, edges: edges),
    );
    const near = Coordinate(lat: 18.47401, lon: -69.885);
    final same = service.calculateRoute(near, near);
    expect(same.distanceMeters, 0);
    expect(same.originApproachMeters, 0);
    expect(same.destinationApproachMeters, 0);
    final snapped = service.calculateRoute(a, near);
    expect(snapped.coordinates, [a]);
    expect(snapped.distanceMeters, 0);
    expect(snapped.destinationApproachMeters, greaterThan(0));
    final result = service.calculateRoute(near, c);
    expect(result.distanceMeters, 9);
    expect(result.originApproachMeters, closeTo(meters(near, a), .001));
  });
  test('puntos inválidos, cobertura y umbral configurable', () {
    final graph = const RoutingGraph(nodes: nodes, edges: edges);
    expect(
      () =>
          RoutingService(graph)
              .calculateRoute(const Coordinate(lat: double.nan, lon: 0), a),
      throwsA(RouteFailure.invalidPoint),
    );
    expect(
      () =>
          RoutingService(graph)
              .calculateRoute(const Coordinate(lat: 0, lon: 0), a),
      throwsA(RouteFailure.tooFarFromGraph),
    );
    expect(
      () => RoutingService(
        graph,
        coverage: pilotBounds,
      ).calculateRoute(const Coordinate(lat: 0, lon: 0), a),
      throwsA(RouteFailure.outsideCoverage),
    );
    expect(
      () => RoutingService(
        graph,
        maxApproach: 1,
      ).calculateRoute(const Coordinate(lat: 18.47404, lon: -69.885), c),
      throwsA(RouteFailure.tooFarFromGraph),
    );
  });
  test(
    'evita duplicados, cancela cálculo obsoleto y se recupera de error',
    () async {
      final controller = HomeController()
        ..router = RoutingService(
          const RoutingGraph(nodes: nodes, edges: edges),
        );
      addTearDown(controller.dispose);
      controller.select(place(a), Selection.origin);
      controller.select(place(d), Selection.destination);
      await controller.calculate();
      expect(controller.routeFailure, RouteFailure.disconnected);
      expect(controller.calculating, isFalse);
      controller.select(place(c), Selection.destination);
      final pending = controller.calculate();
      final duplicate = controller.calculate();
      controller.clear();
      await Future.wait([pending, duplicate]);
      expect(controller.route, isNull);
      expect(controller.calculating, isFalse);
      controller.select(place(a), Selection.origin);
      controller.select(place(c), Selection.destination);
      await controller.calculate();
      final route = controller.route;
      await controller.calculate();
      expect(identical(controller.route, route), isTrue);
      controller.clearRoute();
      expect(controller.route, isNull);
      expect(controller.origin, isNotNull);
      expect(controller.destination, isNotNull);
      await controller.calculate();
      expect(controller.route!.distanceMeters, 9);
      controller.select(place(b), Selection.destination);
      expect(controller.route, isNull);
      expect(controller.routeFailure, isNull);
    },
  );
}
