import '../../core/models/models.dart';

/// Built on the search worker, shared once with UI. Queries inspect only the
/// geographic cells on screen, never scan all national places during a pan.
class PlaceCatalog {
  PlaceCatalog(this.places) {
    for (var i = 0; i < places.length; i++) {
      final c = places[i].coordinate;
      cells
          .putIfAbsent(
            '${(c.lat * 100).floor()}:${(c.lon * 100).floor()}',
            () => [],
          )
          .add(i);
    }
  }
  final List<Place> places;
  final Map<String, List<int>> cells = {};

  List<Place> visible(RegionBounds bounds, double zoom, {int limit = 160}) {
    if (zoom < 14) return const [];
    final south = (bounds.south * 100).floor(),
        north = (bounds.north * 100).floor();
    final west = (bounds.west * 100).floor(),
        east = (bounds.east * 100).floor();
    if ((north - south + 1) * (east - west + 1) > 100) return const [];
    final result = <Place>[];
    for (var y = south; y <= north; y++) {
      for (var x = west; x <= east; x++) {
        for (final i in cells['$y:$x'] ?? const <int>[]) {
          final p = places[i], c = p.coordinate;
          if (p.category == 'calle' || p.category == 'barrio') continue;
          if (zoom < 15 && p.category != 'turismo') continue;
          if (c.lat >= bounds.south &&
              c.lat <= bounds.north &&
              c.lon >= bounds.west &&
              c.lon <= bounds.east) {
            result.add(p);
          }
        }
      }
    }
    final lat = (bounds.south + bounds.north) / 2,
        lon = (bounds.west + bounds.east) / 2;
    double score(Place p) =>
        (p.coordinate.lat - lat) * (p.coordinate.lat - lat) +
        (p.coordinate.lon - lon) * (p.coordinate.lon - lon);
    result.sort((a, b) {
      final priority = (a.category == 'turismo' ? 0 : 1).compareTo(
        b.category == 'turismo' ? 0 : 1,
      );
      return priority != 0 ? priority : score(a).compareTo(score(b));
    });
    return result.take(limit).toList();
  }
}
