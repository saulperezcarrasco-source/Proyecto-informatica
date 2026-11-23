import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/models/models.dart';

const pilotBounds = RegionBounds(
  south: 18.4700,
  north: 18.4780,
  west: -69.8900,
  east: -69.8800,
);
bool inCoverage(Coordinate c) =>
    c.lat.isFinite &&
    c.lon.isFinite &&
    c.lat >= pilotBounds.south &&
    c.lat <= pilotBounds.north &&
    c.lon >= pilotBounds.west &&
    c.lon <= pilotBounds.east;

class RegionData {
  RegionData(
    this.places,
    this.graph,
    this.lines,
    this.areas, {
    required this.manifest,
  });
  final RegionManifest manifest;
  final List<List<Coordinate>> areas;
  final List<Place> places;
  final RoutingGraph graph;
  final List<List<Coordinate>> lines;
}

class RegionRepository {
  Future<RegionData> loadRegion() async {
    Future<dynamic> read(String name) async => jsonDecode(
      utf8.decode(
        (await rootBundle.load('assets/regions/zona_piloto/$name')).buffer
            .asUint8List(),
      ),
    );
    final places = await read('places.json') as List;
    final metadata = await read('manifest.json') as Map<String, dynamic>;
    String field(String key) {
      final value = metadata[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Manifiesto inválido: $key');
      }
      return value;
    }

    final bounds = metadata['bounds'] as Map<String, dynamic>;
    final manifest = RegionManifest(
      id: field('id'),
      name: field('name'),
      version: field('version'),
      source: field('source'),
      attribution: field('attribution'),
      generatedAt: DateTime.parse(field('generatedAt')),
      isDemo: metadata['isDemo'] as bool,
      bounds: RegionBounds(
        south: (bounds['south'] as num).toDouble(),
        north: (bounds['north'] as num).toDouble(),
        west: (bounds['west'] as num).toDouble(),
        east: (bounds['east'] as num).toDouble(),
      ),
    );
    final graph = await read('graph.json') as Map<String, dynamic>;
    final map = await read('map.geojson') as Map<String, dynamic>;
    final areas = (await read('areas.json') as List)
        .map(
          (ring) => (ring['coordinates'] as List)
              .map((p) => coordinateFromPair(p))
              .toList(),
        )
        .toList();
    Coordinate coordinate(dynamic item) {
      final c = Coordinate(
        lat: (item['lat'] as num).toDouble(),
        lon: (item['lon'] as num).toDouble(),
      );
      if (!inCoverage(c)) throw const FormatException('Coordenada inválida');
      return c;
    }

    final nodes = (graph['nodes'] as List)
        .map(
          (n) => GraphNode(
            id: n['id'] as String,
            coordinate: coordinate(n['coordinate']),
          ),
        )
        .toList();
    final ids = nodes.map((n) => n.id).toSet();
    if (ids.length != nodes.length || nodes.isEmpty) {
      throw const FormatException('Nodos inválidos');
    }
    final edges = (graph['edges'] as List).map((e) {
      final weight = (e['distanceMeters'] as num).toDouble();
      if (!weight.isFinite ||
          weight <= 0 ||
          !ids.contains(e['from']) ||
          !ids.contains(e['to'])) {
        throw const FormatException('Arista inválida');
      }
      return GraphEdge(from: e['from'], to: e['to'], distanceMeters: weight);
    }).toList();
    final localPlaces = places
        .map(
          (p) => Place(
            id: p['id'],
            name: p['name'],
            category: p['category'],
            coordinate: coordinate(p['coordinate']),
            aliases: List<String>.from(p['aliases'] ?? []),
          ),
        )
        .toList();
    if (localPlaces.map((p) => p.id).toSet().length != localPlaces.length) {
      throw const FormatException('Lugares duplicados');
    }
    final lines = (map['features'] as List)
        .map(
          (f) => (f['geometry']['coordinates'] as List)
              .map((p) => coordinate({'lat': p[1], 'lon': p[0]}))
              .toList(),
        )
        .toList();
    return RegionData(
      localPlaces,
      RoutingGraph(nodes: nodes, edges: edges),
      lines,
      areas,
      manifest: manifest,
    );
  }
}

Coordinate coordinateFromPair(dynamic p) {
  final c = Coordinate(
    lat: (p[1] as num).toDouble(),
    lon: (p[0] as num).toDouble(),
  );
  if (!inCoverage(c)) {
    throw const FormatException('Área inválida');
  }
  return c;
}
