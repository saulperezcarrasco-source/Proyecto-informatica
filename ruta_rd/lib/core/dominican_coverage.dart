import 'dominican_boundary.dart';
import 'models/models.dart';

const dominicanBounds = RegionBounds(
  south: 17.3,
  west: -72.05,
  north: 20.1,
  east: -68.2,
);

bool inDominicanBounds(Coordinate point) =>
    point.lat.isFinite &&
    point.lon.isFinite &&
    point.lat >= dominicanBounds.south &&
    point.lat <= dominicanBounds.north &&
    point.lon >= dominicanBounds.west &&
    point.lon <= dominicanBounds.east;

/// OSM national boundary, including its boundary points and coastal waters.
/// A bounding rectangle alone would also admit large parts of Haiti.
bool inDominicanRepublic(Coordinate point) {
  if (!inDominicanBounds(point)) return false;
  for (final ring in dominicanBoundary) {
    var inside = false;
    var previous = ring.last;
    for (final current in ring) {
      final dx = current.$2 - previous.$2, dy = current.$1 - previous.$1;
      final cross =
          (point.lon - previous.$2) * dy - (point.lat - previous.$1) * dx;
      if (cross.abs() < 1e-10 &&
          point.lon >= _min(previous.$2, current.$2) - 1e-10 &&
          point.lon <= _max(previous.$2, current.$2) + 1e-10 &&
          point.lat >= _min(previous.$1, current.$1) - 1e-10 &&
          point.lat <= _max(previous.$1, current.$1) + 1e-10) {
        return true;
      }
      if ((current.$1 > point.lat) != (previous.$1 > point.lat) &&
          point.lon <
              (previous.$2 - current.$2) *
                      (point.lat - current.$1) /
                      (previous.$1 - current.$1) +
                  current.$2) {
        inside = !inside;
      }
      previous = current;
    }
    if (inside) return true;
  }
  return false;
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;
