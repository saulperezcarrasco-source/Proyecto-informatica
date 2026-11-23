import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/dominican_coverage.dart';
import '../../core/models/models.dart';
import '../../core/travel_mode.dart';
import 'routing_service.dart';

/// Compact CSR graph; every edge is a consecutive pair of real OSM nodes.
/// The spatial index and A* operate entirely offline in the routing isolate.
class IslandGraph {
  IslandGraph(Uint8List bytes) {
    if (Endian.host != Endian.little || bytes.length < 12) {
      throw RouteFailure.invalidData;
    }
    final header = ByteData.sublistView(bytes);
    final magic = header.getUint32(0, Endian.little);
    if (magic != 0x31494452 && magic != 0x32494452) {
      throw RouteFailure.invalidData;
    }
    count = header.getUint32(4, Endian.little);
    final edges = header.getUint32(8, Endian.little);
    final baseLength = 16 + 16 * count + 8 * edges;
    if (count == 0 ||
        bytes.length < baseLength ||
        (magic == 0x31494452 && bytes.length != baseLength)) {
      throw RouteFailure.invalidData;
    }
    var offset = bytes.offsetInBytes + 12;
    coordinates = Int32List.view(bytes.buffer, offset, count * 2);
    offset += count * 8;
    offsets = Uint32List.view(bytes.buffer, offset, count + 1);
    offset += (count + 1) * 4;
    targets = Uint32List.view(bytes.buffer, offset, edges);
    offset += edges * 4;
    weights = Float32List.view(bytes.buffer, offset, edges);
    offset += edges * 4;
    components = Uint32List.view(bytes.buffer, offset, count);
    if (magic == 0x32494452) {
      if (bytes.length < baseLength + 4) throw RouteFailure.invalidData;
      final turns = header.getUint32(baseLength, Endian.little);
      if (bytes.length != baseLength + 4 + turns * 12) {
        throw RouteFailure.invalidData;
      }
      for (var i = 0; i < turns; i++) {
        final at = baseLength + 4 + i * 12;
        final prev = header.getUint32(at, Endian.little);
        final via = header.getUint32(at + 4, Endian.little);
        final next = header.getUint32(at + 8, Endian.little);
        if (prev >= count || via >= count || next >= count) {
          throw RouteFailure.invalidData;
        }
        prohibited
            .putIfAbsent(via, () => {})
            .putIfAbsent(prev, () => {})
            .add(next);
      }
    }
    if (offsets[0] != 0 || offsets[count] != edges) {
      throw RouteFailure.invalidData;
    }
    final counts = Uint32List(_columns * _rows + 1);
    for (var i = 0; i < count; i++) {
      // The preparation step clips every node and entire edge to the country.
      // Avoid re-running a 6,871-vertex polygon test for every graph node here.
      if (!inDominicanBounds(point(i)) || offsets[i] > offsets[i + 1]) {
        throw RouteFailure.invalidData;
      }
      counts[_cell(i) + 1]++;
    }
    if (prohibited.isNotEmpty) {
      edgeSources = Uint32List(edges);
      for (var node = 0; node < count; node++) {
        edgeSources!.fillRange(offsets[node], offsets[node + 1], node);
      }
    }
    for (var i = 0; i < edges; i++) {
      if (targets[i] >= count || !weights[i].isFinite || weights[i] <= 0) {
        throw RouteFailure.invalidData;
      }
    }
    for (var i = 1; i < counts.length; i++) {
      counts[i] += counts[i - 1];
    }
    gridOffsets = counts;
    gridNodes = Uint32List(count);
    final cursors = Uint32List.fromList(counts);
    for (var i = 0; i < count; i++) {
      gridNodes[cursors[_cell(i)]++] = i;
    }
  }

  static const _cellSize = .02;
  static final _columns =
      ((dominicanBounds.east - dominicanBounds.west) / _cellSize).ceil() + 1;
  static final _rows =
      ((dominicanBounds.north - dominicanBounds.south) / _cellSize).ceil() + 1;
  late final int count;
  late final Int32List coordinates;
  late final Uint32List offsets, targets, components, gridOffsets, gridNodes;
  late final Float32List weights;
  final Map<int, Map<int, Set<int>>> prohibited = {};
  Uint32List? edgeSources;

  Coordinate point(int i) => Coordinate(
    lat: coordinates[i * 2] / 1e7,
    lon: coordinates[i * 2 + 1] / 1e7,
  );
  int _column(double lon) =>
      ((lon - dominicanBounds.west) / _cellSize).floor().clamp(0, _columns - 1);
  int _row(double lat) =>
      ((lat - dominicanBounds.south) / _cellSize).floor().clamp(0, _rows - 1);
  int _cell(int i) =>
      _row(coordinates[i * 2] / 1e7) * _columns +
      _column(coordinates[i * 2 + 1] / 1e7);

  int _nearest(Coordinate p, double maxApproach) {
    var best = -1;
    var distance = maxApproach;
    // Use latitude-dependent longitude span so all nodes inside the radius
    // are considered, including points on cell boundaries.
    final latSpan = maxApproach / 110000;
    final lonSpan = latSpan / math.cos(p.lat * math.pi / 180);
    for (var row = _row(p.lat - latSpan); row <= _row(p.lat + latSpan); row++) {
      for (
        var col = _column(p.lon - lonSpan);
        col <= _column(p.lon + lonSpan);
        col++
      ) {
        final cell = row * _columns + col;
        for (var i = gridOffsets[cell]; i < gridOffsets[cell + 1]; i++) {
          final node = gridNodes[i];
          final d = meters(p, point(node));
          if (d < distance || (d == distance && (best == -1 || node < best))) {
            distance = d;
            best = node;
          }
        }
      }
    }
    if (best == -1) throw RouteFailure.tooFarFromGraph;
    return best;
  }

  RouteResult calculate(
    Coordinate origin,
    Coordinate destination, {
    double maxApproach = 2500,
    TravelMode mode = TravelMode.walking,
  }) {
    if (!maxApproach.isFinite || maxApproach <= 0) {
      throw RouteFailure.invalidData;
    }
    for (final p in [origin, destination]) {
      if (!p.lat.isFinite || !p.lon.isFinite) throw RouteFailure.invalidPoint;
      if (!inDominicanRepublic(p)) throw RouteFailure.outsideCoverage;
    }
    if (origin.lat == destination.lat && origin.lon == destination.lon) {
      return RouteResult(
        coordinates: [origin],
        distanceMeters: 0,
        estimatedMinutes: 0,
        originApproachMeters: 0,
        destinationApproachMeters: 0,
        mode: mode,
      );
    }
    final start = _nearest(origin, maxApproach),
        end = _nearest(destination, maxApproach);
    if (components[start] != components[end]) throw RouteFailure.disconnected;
    if (prohibited.isNotEmpty) {
      return _withTurns(origin, destination, start, end, mode);
    }
    final endPoint = point(end);
    final distances = Float64List(count)..fillRange(0, count, double.infinity);
    final previous = Int32List(count)..fillRange(0, count, -1);
    final heap = _Heap();
    distances[start] = 0;
    heap.add(_Entry(start, 0, meters(point(start), endPoint) * .99999));
    while (heap.isNotEmpty) {
      final current = heap.remove();
      if (current.cost != distances[current.node]) continue;
      if (current.node == end) break;
      for (
        var edge = offsets[current.node];
        edge < offsets[current.node + 1];
        edge++
      ) {
        final next = targets[edge];
        final candidate = current.cost + weights[edge];
        if (candidate < distances[next]) {
          distances[next] = candidate;
          previous[next] = current.node;
          heap.add(
            _Entry(
              next,
              candidate,
              candidate + meters(point(next), endPoint) * .99999,
            ),
          );
        }
      }
    }
    if (!distances[end].isFinite) throw RouteFailure.disconnected;
    final path = <Coordinate>[];
    var node = end;
    while (true) {
      path.add(point(node));
      if (node == start) break;
      node = previous[node];
      if (node < 0 || path.length > count) throw RouteFailure.invalidData;
    }
    return RouteResult(
      coordinates: path.reversed.toList(),
      distanceMeters: distances[end],
      estimatedMinutes: mode.minutes(distances[end]),
      originApproachMeters: meters(origin, point(start)),
      destinationApproachMeters: meters(destination, endPoint),
      mode: mode,
    );
  }

  // Edge states retain the actual incoming road at a junction. A cheaper
  // arrival at the same node must not hide an alternative legal turn.
  RouteResult _withTurns(
    Coordinate origin,
    Coordinate destination,
    int start,
    int end,
    TravelMode mode,
  ) {
    final sentinel = targets.length, total = targets.length + 1;
    final costs = Float64List(total)..fillRange(0, total, double.infinity);
    final previous = Int32List(total)..fillRange(0, total, -1);
    final endPoint = point(end), heap = _Heap();
    costs[sentinel] = 0;
    heap.add(_Entry(sentinel, 0, meters(point(start), endPoint) * .99999));
    var finish = -1;
    while (heap.isNotEmpty) {
      final current = heap.remove();
      if (current.cost != costs[current.node]) continue;
      final node = current.node == sentinel ? start : targets[current.node];
      if (node == end) {
        finish = current.node;
        break;
      }
      final blocked = current.node == sentinel
          ? null
          : prohibited[node]?[edgeSources![current.node]];
      for (var edge = offsets[node]; edge < offsets[node + 1]; edge++) {
        final next = targets[edge];
        if (blocked?.contains(next) ?? false) continue;
        final cost = current.cost + weights[edge];
        if (cost >= costs[edge]) continue;
        costs[edge] = cost;
        previous[edge] = current.node;
        heap.add(
          _Entry(edge, cost, cost + meters(point(next), endPoint) * .99999),
        );
      }
    }
    if (finish < 0) throw RouteFailure.disconnected;
    final path = <Coordinate>[];
    var state = finish;
    while (state != sentinel) {
      path.add(point(targets[state]));
      state = previous[state];
      if (state < 0 || path.length > total) throw RouteFailure.invalidData;
    }
    path.add(point(start));
    return RouteResult(
      coordinates: path.reversed.toList(),
      distanceMeters: costs[finish],
      estimatedMinutes: mode.minutes(costs[finish]),
      originApproachMeters: meters(origin, point(start)),
      destinationApproachMeters: meters(destination, endPoint),
      mode: mode,
    );
  }
}

class _Entry {
  const _Entry(this.node, this.cost, this.priority);
  final int node;
  final double cost, priority;
}

class _Heap {
  final _items = <_Entry>[];
  bool get isNotEmpty => _items.isNotEmpty;
  void add(_Entry value) {
    _items.add(value);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_items[parent].priority <= value.priority) break;
      _items[i] = _items[parent];
      i = parent;
    }
    _items[i] = value;
  }

  _Entry remove() {
    final result = _items.first;
    final last = _items.removeLast();
    if (_items.isEmpty) return result;
    var i = 0;
    while (i * 2 + 1 < _items.length) {
      var child = i * 2 + 1;
      if (child + 1 < _items.length &&
          _items[child + 1].priority < _items[child].priority) {
        child++;
      }
      if (last.priority <= _items[child].priority) break;
      _items[i] = _items[child];
      i = child;
    }
    _items[i] = last;
    return result;
  }
}
