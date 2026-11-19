/// Coordenadas geográficas en grados decimales.
class Coordinate {
  const Coordinate({required this.lat, required this.lon});
  final double lat, lon;
}

class RegionBounds {
  const RegionBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
  final double south, west, north, east;
}

class RegionManifest {
  const RegionManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.bounds,
    required this.source,
    required this.attribution,
    required this.generatedAt,
    required this.isDemo,
  });
  final String id, name, version, source, attribution;
  final RegionBounds bounds;
  final DateTime generatedAt;
  final bool isDemo;
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.coordinate,
    this.aliases = const [],
  });
  final String id, name, category;
  final Coordinate coordinate;
  final List<String> aliases;
}

class GraphNode {
  const GraphNode({required this.id, required this.coordinate});
  final String id;
  final Coordinate coordinate;
}

class GraphEdge {
  const GraphEdge({
    required this.from,
    required this.to,
    required this.distanceMeters,
  });
  final String from, to;
  final double distanceMeters;
}

class RoutingGraph {
  const RoutingGraph({required this.nodes, required this.edges});
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
}

class RouteResult {
  const RouteResult({
    required this.coordinates,
    required this.distanceMeters,
    required this.estimatedMinutes,
    required this.originApproachMeters,
    required this.destinationApproachMeters,
  });
  final List<Coordinate> coordinates;
  final double distanceMeters,
      estimatedMinutes,
      originApproachMeters,
      destinationApproachMeters;
}

enum RouteFailure {
  invalidPoint,
  outsideCoverage,
  tooFarFromGraph,
  disconnected,
  invalidData,
}
