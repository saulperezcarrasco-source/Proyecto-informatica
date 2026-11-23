import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/core/dominican_coverage.dart';
import 'package:ruta_rd/features/routing/island_graph.dart';
import 'package:ruta_rd/features/routing/routing_service.dart';

Uint8List fixture() {
  final bytes = Uint8List(16 + 16 * 4 + 8 * 3);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x31494452, Endian.little);
  data.setUint32(4, 4, Endian.little);
  data.setUint32(8, 3, Endian.little);
  var offset = 12;
  for (final value in [
    191300000,
    -703946400,
    191305000,
    -703946400,
    191310000,
    -703946400,
    191400000,
    -703946400,
  ]) {
    data.setInt32(offset, value, Endian.little);
    offset += 4;
  }
  for (final value in [0, 2, 3, 3, 3, 1, 2, 2]) {
    data.setUint32(offset, value, Endian.little);
    offset += 4;
  }
  for (final value in [150.0, 900.0, 150.0]) {
    data.setFloat32(offset, value, Endian.little);
    offset += 4;
  }
  for (final value in [0, 0, 0, 3]) {
    data.setUint32(offset, value, Endian.little);
    offset += 4;
  }
  return bytes;
}

void main() {
  test(
    'A* respeta pesos, aristas dirigidas y desconexiones sin inventar enlaces',
    () {
      final graph = IslandGraph(fixture());
      final result = graph.calculate(graph.point(0), graph.point(2));
      expect(result.distanceMeters, 300);
      expect(result.coordinates.map((p) => p.lat), [19.13, 19.1305, 19.131]);
      expect(
        () => graph.calculate(graph.point(2), graph.point(0)),
        throwsA(RouteFailure.disconnected),
      );
      expect(
        () => graph.calculate(graph.point(0), graph.point(3)),
        throwsA(RouteFailure.disconnected),
      );
      expect(graph.calculate(graph.point(0), graph.point(0)).distanceMeters, 0);
    },
  );
  test('valida archivo, cobertura y distancia de aproximación', () {
    expect(() => IslandGraph(Uint8List(20)), throwsA(RouteFailure.invalidData));
    final truncated = fixture().sublist(0, 100);
    expect(() => IslandGraph(truncated), throwsA(RouteFailure.invalidData));
    final invalid = fixture();
    ByteData.sublistView(invalid).setFloat32(76, double.nan, Endian.little);
    expect(() => IslandGraph(invalid), throwsA(RouteFailure.invalidData));
    final graph = IslandGraph(fixture());
    expect(
      () => graph.calculate(const Coordinate(lat: 0, lon: 0), graph.point(0)),
      throwsA(RouteFailure.outsideCoverage),
    );
    expect(
      () => graph.calculate(
        const Coordinate(lat: double.nan, lon: -70),
        graph.point(0),
      ),
      throwsA(RouteFailure.invalidPoint),
    );
    expect(
      () => graph.calculate(
        const Coordinate(lat: 19.2, lon: -70.39),
        graph.point(0),
        maxApproach: 10,
      ),
      throwsA(RouteFailure.tooFarFromGraph),
    );
  });

  late IslandGraph real;
  setUpAll(() async {
    real = IslandGraph(
      Uint8List.fromList(
        gzip.decode(
          await File('assets/routing/dominican-walking.rdi').readAsBytes(),
        ),
      ),
    );
  });
  test('rutas de RD usan solo aristas OSM y permanecen dentro del país', () {
    final index = <(int, int), List<int>>{};
    for (var i = 0; i < real.count; i++) {
      index
          .putIfAbsent((
            real.coordinates[2 * i],
            real.coordinates[2 * i + 1],
          ), () => [])
          .add(i);
    }
    const samples = [
      [
        Coordinate(lat: 19.4517, lon: -70.697),
        Coordinate(lat: 19.793, lon: -70.688),
      ],
      [
        Coordinate(lat: 18.4861, lon: -69.9312),
        Coordinate(lat: 18.582, lon: -68.405),
      ],
      [
        Coordinate(lat: 18.2085, lon: -71.1008),
        Coordinate(lat: 18.4861, lon: -69.9312),
      ],
      [
        Coordinate(lat: 19.54878, lon: -71.70829),
        Coordinate(lat: 19.4517, lon: -70.697),
      ],
      [
        Coordinate(lat: 19.793, lon: -70.688),
        Coordinate(lat: 19.4517, lon: -70.697),
      ],
      [
        Coordinate(lat: 18.582, lon: -68.405),
        Coordinate(lat: 18.4861, lon: -69.9312),
      ],
      [
        Coordinate(lat: 18.4861, lon: -69.9312),
        Coordinate(lat: 18.2085, lon: -71.1008),
      ],
      [
        Coordinate(lat: 19.4517, lon: -70.697),
        Coordinate(lat: 19.54878, lon: -71.70829),
      ],
    ];
    for (final sample in samples) {
      final watch = Stopwatch()..start();
      final route = real.calculate(sample[0], sample[1]);
      expect(route.coordinates.every(inDominicanRepublic), isTrue);
      watch.stop();
      expect(
        route.distanceMeters,
        greaterThan(meters(sample[0], sample[1]) - 3000),
      );
      var sum = 0.0;
      for (var p = 1; p < route.coordinates.length; p++) {
        List<int> nodes(Coordinate c) =>
            index[((c.lat * 1e7).round(), (c.lon * 1e7).round())]!;
        final from = nodes(route.coordinates[p - 1]),
            to = nodes(route.coordinates[p]);
        double? weight;
        for (final a in from) {
          for (var edge = real.offsets[a]; edge < real.offsets[a + 1]; edge++) {
            if (to.contains(real.targets[edge])) weight = real.weights[edge];
          }
        }
        expect(weight, isNotNull, reason: 'Tramo $p sin una arista OSM');
        sum += weight!;
      }
      expect(sum, closeTo(route.distanceMeters, .1));
      // A geometric distance check alone would not catch invented crossings.
      // The preceding assertion checks actual directed graph membership.
      // ignore: avoid_print
      print(
        'ISLAND_ROUTE ${sample[0].lat},${sample[0].lon} -> ${sample[1].lat},${sample[1].lon}: ${route.distanceMeters.round()} m, ${route.coordinates.length} vertices, ${watch.elapsedMilliseconds} ms; approaches ${route.originApproachMeters.round()}/${route.destinationApproachMeters.round()} m',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('rechaza Haití dentro del encuadre', () {
    expect(
      () => real.calculate(
        const Coordinate(lat: 19.55, lon: -71.73),
        const Coordinate(lat: 19.4517, lon: -70.697),
      ),
      throwsA(RouteFailure.outsideCoverage),
    );
  });
  test('par 10: desconexión real y recuperación con los mismos datos', () {
    const start = Coordinate(lat: 19.4517, lon: -70.697);
    final connected = real
        .calculate(start, const Coordinate(lat: 19.793, lon: -70.688))
        .coordinates
        .first;
    final mainNode = Iterable<int>.generate(real.count).firstWhere(
      (i) =>
          real.point(i).lat == connected.lat &&
          real.point(i).lon == connected.lon,
    );
    final separate = Iterable<int>.generate(real.count).firstWhere(
      (i) =>
          real.components[i] != real.components[mainNode] &&
          real.offsets[i] < real.offsets[i + 1] &&
          inDominicanRepublic(real.point(i)),
    );
    final end = real.point(separate);
    expect(
      () => real.calculate(start, end),
      throwsA(RouteFailure.disconnected),
    );
    // A failed request must leave the graph usable for a corrected pair.
    expect(real.calculate(start, connected).coordinates, isNotEmpty);
    // ignore: avoid_print
    print(
      'ACCEPTANCE_DISCONNECTED ${start.lat},${start.lon} -> '
      '${end.lat},${end.lon}; recovered=true',
    );
  });
}
