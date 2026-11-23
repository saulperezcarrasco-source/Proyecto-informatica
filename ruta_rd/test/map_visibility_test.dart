import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/core/map_visibility.dart';

List<Coordinate> ring(List<(double, double)> points) => [
  for (final p in points) Coordinate(lat: p.$2, lon: p.$1),
];
void main() {
  final square = ring([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]);
  test('solo omite máscara si toda la vista es interior', () {
    expect(
      viewportInsideRing(
        const RegionBounds(south: 2, west: 2, north: 8, east: 8),
        square,
      ),
      isTrue,
    );
    expect(
      viewportInsideRing(
        const RegionBounds(south: 2, west: 0, north: 8, east: 8),
        square,
      ),
      isFalse,
    );
    expect(
      viewportInsideRing(
        const RegionBounds(south: 2, west: 8, north: 8, east: 12),
        square,
      ),
      isFalse,
    );
    expect(
      viewportInsideRing(
        const RegionBounds(south: 12, west: 12, north: 13, east: 13),
        square,
      ),
      isFalse,
    );
  });
  test('cuatro esquinas interiores no bastan en un país cóncavo', () {
    final concave = ring([
      (0, 0),
      (10, 0),
      (10, 10),
      (6, 10),
      (6, 4),
      (4, 4),
      (4, 10),
      (0, 10),
      (0, 0),
    ]);
    expect(
      viewportInsideRing(
        const RegionBounds(south: 2, west: 2, north: 8, east: 8),
        concave,
      ),
      isFalse,
    );
    expect(
      viewportInsideRing(
        const RegionBounds(south: 1, west: 1, north: 3, east: 3),
        concave,
      ),
      isTrue,
    );
  });
}
