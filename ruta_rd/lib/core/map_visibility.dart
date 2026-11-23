import 'models/models.dart';

/// A conservative proof that the whole viewport is inside one simple polygon.
/// An edge whose bounding box even touches the view forces the exact mask.
bool viewportInsideRing(RegionBounds view, List<Coordinate> ring) {
  if (ring.length < 4 ||
      ![
        view.south,
        view.west,
        view.north,
        view.east,
      ].every((v) => v.isFinite)) {
    return false;
  }
  bool inside(double lat, double lon) {
    var result = false;
    var previous = ring.last;
    for (final p in ring) {
      if ((p.lat > lat) != (previous.lat > lat) &&
          lon <
              (previous.lon - p.lon) * (lat - p.lat) / (previous.lat - p.lat) +
                  p.lon) {
        result = !result;
      }
      previous = p;
    }
    return result;
  }

  if (!inside(view.south, view.west) ||
      !inside(view.south, view.east) ||
      !inside(view.north, view.west) ||
      !inside(view.north, view.east)) {
    return false;
  }
  var previous = ring.last;
  for (final p in ring) {
    final minLat = p.lat < previous.lat ? p.lat : previous.lat;
    final maxLat = p.lat > previous.lat ? p.lat : previous.lat;
    final minLon = p.lon < previous.lon ? p.lon : previous.lon;
    final maxLon = p.lon > previous.lon ? p.lon : previous.lon;
    if (minLat <= view.north &&
        maxLat >= view.south &&
        minLon <= view.east &&
        maxLon >= view.west) {
      return false;
    }
    previous = p;
  }
  return true;
}
