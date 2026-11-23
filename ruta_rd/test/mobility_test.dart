import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/core/travel_mode.dart';
import 'package:ruta_rd/features/routing/island_graph.dart';
import 'package:ruta_rd/features/routing/routing_service.dart';

const points = [
  Coordinate(lat: 18.473, lon: -69.886),
  Coordinate(lat: 18.474, lon: -69.886),
  Coordinate(lat: 18.474, lon: -69.884),
  Coordinate(lat: 18.473, lon: -69.887),
];

Uint8List fixture({bool restricted = true}) {
  // 0->1 is cheaper than 0->3->1, but its turn 0->1->2 is prohibited.
  const edges = [(0, 1), (0, 3), (1, 2), (3, 1)];
  final data = ByteData(16 + 16 * 4 + 8 * 4 + 4 + (restricted ? 12 : 0));
  var at = 0;
  void uint(int n) {
    data.setUint32(at, n, Endian.little);
    at += 4;
  }

  uint(0x32494452);
  uint(4);
  uint(4);
  for (final p in points) {
    data.setInt32(at, (p.lat * 1e7).round(), Endian.little);
    at += 4;
    data.setInt32(at, (p.lon * 1e7).round(), Endian.little);
    at += 4;
  }
  for (final n in [0, 2, 3, 3, 4]) {
    uint(n);
  }
  for (final e in edges) {
    uint(e.$2);
  }
  for (final e in edges) {
    data.setFloat32(
      at,
      (meters(points[e.$1], points[e.$2]) * 100).ceil() / 100,
      Endian.little,
    );
    at += 4;
  }
  for (var i = 0; i < 4; i++) {
    uint(0);
  }
  uint(restricted ? 1 : 0);
  if (restricted) {
    uint(0);
    uint(1);
    uint(2);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('tiempos distintos por transporte y modos propagados', () {
    expect(TravelMode.walking.minutes(1000), closeTo(13.333, .001));
    expect(TravelMode.bicycle.minutes(1000), 4);
    expect(TravelMode.car.minutes(1000), 1.5);
    expect(TravelMode.motorcycle.minutes(1000), closeTo(1.714, .001));
  });
  test('un giro prohibido conserva la alternativa que llega por otra vía', () {
    final graph = IslandGraph(fixture());
    final route = graph.calculate(
      points[0],
      points[2],
      mode: TravelMode.car,
      maxApproach: 10,
    );
    expect(route.coordinates.map((p) => p.lon).toList(), [
      points[0].lon,
      points[3].lon,
      points[1].lon,
      points[2].lon,
    ]);
    expect(route.mode, TravelMode.car);
    expect(
      route.estimatedMinutes,
      closeTo(TravelMode.car.minutes(route.distanceMeters), .0001),
    );
    final unrestricted = IslandGraph(fixture(restricted: false))
        .calculate(points[0], points[2], maxApproach: 10);
    expect(unrestricted.distanceMeters, lessThan(route.distanceMeters));
  });
  test('no inventa la vuelta contra sentido ni acepta RDI2 truncado', () {
    final data = fixture();
    expect(
      () => IslandGraph(data).calculate(points[2], points[0], maxApproach: 10),
      throwsA(RouteFailure.disconnected),
    );
    expect(
      () => IslandGraph(Uint8List.sublistView(data, 0, data.length - 4)),
      throwsA(RouteFailure.invalidData),
    );
  });
}
