import 'dart:math' as math;

import '../../core/models/models.dart';

double meters(Coordinate a, Coordinate b) {
  const rad = math.pi / 180;
  final h =
      math.pow(math.sin((b.lat - a.lat) * rad / 2), 2) +
      math.cos(a.lat * rad) *
          math.cos(b.lat * rad) *
          math.pow(math.sin((b.lon - a.lon) * rad / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
}

class RoutingService {
  RoutingService(this.graph, {this.maxApproach = 100, this.coverage}) {
    if (!maxApproach.isFinite || maxApproach <= 0) {
      throw RouteFailure.invalidData;
    }
    for (final n in graph.nodes) {
      if (n.id.isEmpty ||
          nodes.containsKey(n.id) ||
          !n.coordinate.lat.isFinite ||
          !n.coordinate.lon.isFinite ||
          n.coordinate.lat.abs() > 90 ||
          n.coordinate.lon.abs() > 180) {
        throw RouteFailure.invalidData;
      }
      nodes[n.id] = n;
      adjacency[n.id] = [];
    }
    for (final e in graph.edges) {
      if (!nodes.containsKey(e.from) ||
          !nodes.containsKey(e.to) ||
          !e.distanceMeters.isFinite ||
          e.distanceMeters <= 0) {
        throw RouteFailure.invalidData;
      }
      adjacency[e.from]!.add(e);
    }
    if (nodes.isEmpty) throw RouteFailure.invalidData;
  }
  final RoutingGraph graph;
  final double maxApproach;
  final RegionBounds? coverage;
  final nodes = <String, GraphNode>{};
  final adjacency = <String, List<GraphEdge>>{};

  RouteResult calculateRoute(Coordinate origin, Coordinate destination) {
    for (final p in [origin, destination]) {
      if (!p.lat.isFinite ||
          !p.lon.isFinite ||
          p.lat.abs() > 90 ||
          p.lon.abs() > 180) {
        throw RouteFailure.invalidPoint;
      }
      final bounds = coverage;
      if (bounds != null &&
          (p.lat < bounds.south ||
              p.lat > bounds.north ||
              p.lon < bounds.west ||
              p.lon > bounds.east)) {
        throw RouteFailure.outsideCoverage;
      }
    }
    if (origin.lat == destination.lat && origin.lon == destination.lon) {
      return RouteResult(
        coordinates: [origin],
        distanceMeters: 0,
        estimatedMinutes: 0,
        originApproachMeters: 0,
        destinationApproachMeters: 0,
      );
    }
    GraphNode nearest(Coordinate c) => nodes.values.reduce((a, b) {
      final comparison = meters(
        c,
        a.coordinate,
      ).compareTo(meters(c, b.coordinate));
      return comparison < 0 || (comparison == 0 && a.id.compareTo(b.id) < 0)
          ? a
          : b;
    });
    final start = nearest(origin);
    final end = nearest(destination);
    final da = meters(origin, start.coordinate);
    final db = meters(destination, end.coordinate);
    if (da > maxApproach || db > maxApproach) {
      throw RouteFailure.tooFarFromGraph;
    }
    final dist = <String, double>{start.id: 0};
    final previous = <String, String>{};
    final visited = <String>{};
    while (true) {
      final pending = dist.keys.where((id) => !visited.contains(id)).toList();
      if (pending.isEmpty) throw RouteFailure.disconnected;
      final current = pending.reduce((a, b) => dist[a]! <= dist[b]! ? a : b);
      if (current == end.id) break;
      visited.add(current);
      for (final edge in adjacency[current]!) {
        final cost = dist[current]! + edge.distanceMeters;
        if (cost < (dist[edge.to] ?? double.infinity)) {
          dist[edge.to] = cost;
          previous[edge.to] = current;
        }
      }
    }
    final path = <Coordinate>[];
    var id = end.id;
    while (true) {
      path.add(nodes[id]!.coordinate);
      if (id == start.id) break;
      id = previous[id]!;
    }
    return RouteResult(
      coordinates: path.reversed.toList(),
      distanceMeters: dist[end.id]!,
      estimatedMinutes: dist[end.id]! / 75,
      originApproachMeters: da,
      destinationApproachMeters: db,
    );
  }
}
