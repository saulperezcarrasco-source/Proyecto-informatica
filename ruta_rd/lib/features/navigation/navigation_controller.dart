import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/dominican_coverage.dart';
import '../location/location_service.dart';
import '../routing/routing_service.dart';
import '../../core/distance_format.dart';
import '../../core/travel_mode.dart';

double bearing(Coordinate a, Coordinate b) {
  const rad = math.pi / 180;
  final d = (b.lon - a.lon) * rad;
  return (math.atan2(
                math.sin(d) * math.cos(b.lat * rad),
                math.cos(a.lat * rad) * math.sin(b.lat * rad) -
                    math.sin(a.lat * rad) * math.cos(b.lat * rad) * math.cos(d),
              ) /
              rad +
          360) %
      360;
}

class RouteProgress {
  RouteProgress(this.points) {
    if (points.isEmpty) {
      throw ArgumentError('La ruta necesita coordenadas');
    }
    cumulative = [0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(cumulative.last + meters(points[i - 1], points[i]));
      final a = points[i - 1], b = points[i];
      segmentBearings.add(bearing(a, b));
      final y0 = (math.min(a.lat, b.lat) * 500).floor(),
          y1 = (math.max(a.lat, b.lat) * 500).floor();
      final x0 = (math.min(a.lon, b.lon) * 500).floor(),
          x1 = (math.max(a.lon, b.lon) * 500).floor();
      if ((y1 - y0 + 1) * (x1 - x0 + 1) > 64) {
        _longSegments.add(i - 1);
        continue;
      }
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          _cells.putIfAbsent('$y:$x', () => []).add(i - 1);
        }
      }
    }
    for (var i = 1; i < points.length - 1; i++) {
      if (cumulative[i] - cumulative[i - 1] < 4 ||
          cumulative[i + 1] - cumulative[i] < 4) {
        continue;
      }
      final angle =
          (segmentBearings[i] - segmentBearings[i - 1] + 540) % 360 - 180;
      if (angle.abs() > 35) turns.add((at: cumulative[i], right: angle > 0));
    }
  }
  final List<Coordinate> points;
  late final List<double> cumulative;
  final Map<String, List<int>> _cells = {};
  final List<int> _longSegments = [];
  final List<double> segmentBearings = [];
  final List<({double at, bool right})> turns = [];
  int candidatesExamined = 0;
  int segmentsVisited = 0;
  int turnSearchSteps = 0;
  int _lowerBound(double value) {
    var lo = 0, hi = cumulative.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (cumulative[mid] < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  ({double at, bool right})? nextTurn(double after, double before) {
    var lo = 0, hi = turns.length;
    turnSearchSteps = 0;
    while (lo < hi) {
      turnSearchSteps++;
      final mid = (lo + hi) ~/ 2;
      if (turns[mid].at < after) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < turns.length && turns[lo].at < before ? turns[lo] : null;
  }

  double get length => cumulative.last;
  ({double along, double away, int segment, Coordinate point}) project(
    Coordinate p,
    double previous, {
    double? maxForward,
    double? maxBackward,
    double? heading,
  }) {
    if (points.length == 1) {
      return (
        along: 0,
        away: meters(p, points.first),
        segment: 0,
        point: points.first,
      );
    }
    final minAlong = math.max(0.0, previous - (maxBackward ?? 25));
    final maxAlong = math.min(length, previous + (maxForward ?? length));
    final first = math.max(0, _lowerBound(minAlong) - 1);
    final last = math.min(points.length - 2, _lowerBound(maxAlong));
    final nearby = <int>{};
    final bounded = maxForward != null && last - first < 1024;
    final cy = (p.lat * 500).floor(), cx = (p.lon * 500).floor();
    if (!bounded) {
      nearby.addAll(_longSegments);
      for (var y = cy - 2; y <= cy + 2; y++) {
        for (var x = cx - 2; x <= cx + 2; x++) {
          nearby.addAll(_cells['$y:$x'] ?? const []);
        }
      }
    }
    final candidates = bounded || nearby.isEmpty
        ? Iterable<int>.generate(
            math.max(0, last - first + 1),
            (i) => first + i,
          )
        : (nearby.toList()..sort());
    var best = double.infinity,
        bestAway = double.infinity,
        along = previous,
        segment = 0;
    Coordinate projected = p;
    const scale = 111320.0;
    final cos = math.cos(p.lat * math.pi / 180);
    candidatesExamined = 0;
    segmentsVisited = 0;
    for (final i in candidates) {
      segmentsVisited++;
      if (cumulative[i + 1] < minAlong || cumulative[i] > maxAlong) {
        continue;
      }
      candidatesExamined++;
      final a = points[i], b = points[i + 1];
      final ax = (a.lon - p.lon) * scale * cos, ay = (a.lat - p.lat) * scale;
      final dx = (b.lon - a.lon) * scale * cos, dy = (b.lat - a.lat) * scale;
      final len = dx * dx + dy * dy;
      final segmentLength = cumulative[i + 1] - cumulative[i];
      if (segmentLength <= 0) continue;
      final lower = ((minAlong - cumulative[i]) / segmentLength).clamp(
        0.0,
        1.0,
      );
      final upper = ((maxAlong - cumulative[i]) / segmentLength).clamp(
        0.0,
        1.0,
      );
      final t = len == 0
          ? lower
          : (-(ax * dx + ay * dy) / len).clamp(lower, upper);
      final s = cumulative[i] + t * (cumulative[i + 1] - cumulative[i]);
      final away = math.sqrt(
        (ax + t * dx) * (ax + t * dx) + (ay + t * dy) * (ay + t * dy),
      );
      final continuity = maxForward == null
          ? 0.0
          : math.min(12.0, (s - previous).abs() * .04);
      final direction = heading == null
          ? 0.0
          : (((segmentBearings[i] - heading + 540) % 360 - 180).abs() /
                180 *
                8);
      final score = away + continuity + direction;
      if (score < best) {
        best = score;
        bestAway = away;
        along = s;
        segment = i;
        projected = Coordinate(
          lat: a.lat + t * (b.lat - a.lat),
          lon: a.lon + t * (b.lon - a.lon),
        );
      }
    }
    return (along: along, away: bestAway, segment: segment, point: projected);
  }
}

List<Coordinate> _navigationPoints(
  RouteResult route,
  Coordinate? origin,
  Coordinate destination,
) => [
  if (origin != null && meters(origin, route.coordinates.first) > .5) origin,
  ...route.coordinates,
  if (meters(route.coordinates.last, destination) > .5) destination,
];

/// Indexed guidance: continuity gates prevent jumps to future crossings.
/// Original A/B and RouteResult stay immutable; GPS never runs A* per fix.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required this.route,
    required this.destination,
    required this.location,
    Coordinate? origin,
  }) : progress = RouteProgress(_navigationPoints(route, origin, destination)) {
    _roadStart = origin != null && meters(origin, route.coordinates.first) > .5
        ? meters(origin, route.coordinates.first)
        : 0;
    final last = meters(route.coordinates.last, destination);
    _roadEnd = progress.length - (last > .5 ? last : 0);
    instructionMeters = remainingMeters;
  }
  final RouteResult route;
  final Coordinate destination;
  final LocationService location;
  final RouteProgress progress;
  late final double _roadStart, _roadEnd;
  StreamSubscription<LocationReading>? _subscription;
  Timer? _stale;
  bool active = false,
      disposed = false,
      follow = true,
      arrived = false,
      offRoute = false;
  Coordinate? position, _trustedRaw;
  Coordinate? _uncertainPosition, _headingAnchor;
  bool _guidanceReliable = false;
  int _deviationFixes = 0;
  Object? _lastPresentation;
  int _cameraRevision = 0;
  int get cameraRevision => _cameraRevision;
  Coordinate? get displayPosition => _uncertainPosition ?? position;
  bool get isApproximatePosition => _uncertainPosition != null;
  bool get hasReliablePosition => position != null && _guidanceReliable;
  DateTime? lastFix;
  final Stopwatch _sampleClock = Stopwatch()..start();
  int? _trustedSampleMillis, _lastSampleMillis;
  double heading = 0, accuracy = 0, travelled = 0;
  double? _movingSpeed;
  LocationFailure? failure;
  String status = 'Pulsa iniciar para seguir tu ubicación.',
      instruction = 'Continúa por la ruta';
  double instructionMeters = 0;
  @override
  void notifyListeners() {
    int? quantize(double? value) =>
        value == null ? null : (value * 1e6).round();
    final presentation = (
      quantize(displayPosition?.lat),
      quantize(displayPosition?.lon),
      heading.round(),
      accuracy.round(),
      remainingMeters.floor(),
      remainingMinutes,
      instruction,
      instructionMeters.floor(),
      status,
      failure,
      active,
      follow,
      arrived,
      offRoute,
      hasReliablePosition,
      cameraRevision,
    );
    if (presentation == _lastPresentation) return;
    _lastPresentation = presentation;
    super.notifyListeners();
  }

  double get remainingMeters =>
      arrived ? 0 : math.max(0, progress.length - travelled);
  int get remainingMinutes {
    if (arrived) return 0;
    final road = math.max(0.0, _roadEnd - math.max(travelled, _roadStart));
    final access = math.max(0.0, remainingMeters - road);
    final speed = _movingSpeed == null
        ? route.mode.metersPerMinute
        : _movingSpeed! * 60;
    return (road / speed + access / 75).ceil();
  }

  void start() {
    if (active || disposed) {
      return;
    }
    active = true;
    failure = null;
    if (_lastSampleMillis == null ||
        _sampleClock.elapsedMilliseconds - _lastSampleMillis! > 15000) {
      _guidanceReliable = false;
    }
    status = 'Buscando GPS satelital…';
    notifyListeners();
    _subscription = location.watch().listen(
      accept,
      onError: (Object error) {
        if (disposed) {
          return;
        }
        failure = error is LocationException
            ? error.failure
            : LocationFailure.unavailable;
        status = error is LocationException
            ? switch (error.failure) {
                LocationFailure.precisePermissionRequired =>
                  'Activa «Usar ubicación precisa» en los permisos de la app.',
                LocationFailure.permissionDenied ||
                LocationFailure.permissionDeniedForever => 'Permiso GPS no concedido. Puedes volver al mapa y elegir puntos.',
                LocationFailure.serviceDisabled =>
                  'Activa la ubicación del teléfono para navegar.',
                LocationFailure.outsideCoverage =>
                  'Tu ubicación está fuera de RD.',
                _ =>
                  'No se pudo seguir la ubicación. Reintenta con GPS activado.',
              }
            : 'Se perdió la ubicación. Reintenta con GPS activado.';
        stop(keepStatus: true);
      },
      onDone: () {
        if (active && !disposed) {
          status = 'El seguimiento GPS se interrumpió.';
          stop(keepStatus: true);
        }
      },
    );
    _stale = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!disposed &&
          active &&
          (_lastSampleMillis == null ||
              _sampleClock.elapsedMilliseconds - _lastSampleMillis! > 15000)) {
        _guidanceReliable = false;
        status = lastFix == null
            ? 'Buscando satélites GPS. Acércate a una ventana o sal al aire libre; sin internet puede tardar más.'
            : 'Esperando una posición GPS reciente…';
        notifyListeners();
      }
    });
  }

  void accept(LocationReading reading) {
    if (disposed || !active || !reading.isValid) {
      return;
    }
    final now = DateTime.now(), stamp = reading.timestamp ?? DateTime.now();
    final age = now.difference(stamp).inMilliseconds;
    final sampleMillis = _sampleClock.elapsedMilliseconds - age;
    if (age > 15000 ||
        age < -5000 ||
        (reading.timestamp != null &&
            _lastSampleMillis != null &&
            sampleMillis <= _lastSampleMillis!)) {
      return;
    }
    if (!inDominicanRepublic(reading.coordinate)) {
      _guidanceReliable = false;
      status = 'Tu ubicación está fuera de RD.';
      notifyListeners();
      return;
    }
    if (reading.accuracy > 35) {
      lastFix = stamp;
      _lastSampleMillis = sampleMillis;
      accuracy = reading.accuracy;
      _guidanceReliable = false;
      _uncertainPosition = accuracy <= 200 ? reading.coordinate : null;
      status =
          'Ubicación aproximada: ±${accuracy.round()} m. Avance en espera.';
      notifyListeners();
      return;
    }
    final step = _trustedRaw == null
        ? 0.0
        : meters(_trustedRaw!, reading.coordinate);
    final elapsed = _trustedSampleMillis == null
        ? 0.0
        : (sampleMillis - _trustedSampleMillis!) / 1000;
    final maximumSpeed = switch (route.mode) {
      TravelMode.walking => 8.0,
      TravelMode.bicycle => 25.0,
      TravelMode.car || TravelMode.motorcycle => 70.0,
    };
    if (reading.timestamp != null &&
        _trustedRaw != null &&
        elapsed >= 0 &&
        elapsed < 300 &&
        step >
            maximumSpeed * elapsed +
                reading.accuracy +
                accuracy.clamp(0, 35) +
                3) {
      _guidanceReliable = false;
      status = 'Posición GPS inestable. Esperando una lectura fiable…';
      notifyListeners();
      return;
    }
    lastFix = stamp;
    _lastSampleMillis = sampleMillis;
    accuracy = reading.accuracy;
    final continuous = _trustedRaw != null && elapsed >= 0 && elapsed < 300;
    final window = math.max(
      40.0,
      elapsed >= 15
          ? maximumSpeed * elapsed + accuracy * 2
          : step * 2 + accuracy * 2,
    );
    final nearOrigin =
        _trustedRaw == null &&
        meters(reading.coordinate, progress.points.first) <
            math.max(35, accuracy * 2);
    final fix = progress.project(
      reading.coordinate,
      travelled,
      maxForward: continuous
          ? window
          : nearOrigin
          ? math.max(80, accuracy * 4)
          : null,
      maxBackward: continuous ? window : progress.length,
      heading: reading.heading,
    );
    if (!fix.away.isFinite) {
      _guidanceReliable = false;
      status = 'Esperando confirmar la posición sobre el recorrido…';
      notifyListeners();
      return;
    }
    final old = _trustedRaw;
    _uncertainPosition = null;
    _guidanceReliable = true;
    _trustedRaw = reading.coordinate;
    _trustedSampleMillis = sampleMillis;
    final departed = fix.away > math.max(25, accuracy * 1.8);
    _deviationFixes = departed ? _deviationFixes + 1 : 0;
    if (offRoute) {
      offRoute = fix.away > math.max(12, accuracy * 1.2);
    } else {
      offRoute = fix.away > 120 || _deviationFixes >= 2;
    }
    position = !offRoute && fix.away <= 12 ? fix.point : reading.coordinate;
    double? course;
    if (reading.heading != null && reading.heading!.isFinite) {
      course = reading.heading! % 360;
    } else if (_headingAnchor != null &&
        meters(_headingAnchor!, reading.coordinate) >=
            math.max(6, accuracy * 1.2)) {
      course = bearing(_headingAnchor!, reading.coordinate);
      _headingAnchor = reading.coordinate;
    } else if (old == null && fix.segment + 1 < progress.points.length) {
      course = bearing(
        progress.points[fix.segment],
        progress.points[fix.segment + 1],
      );
    }
    _headingAnchor ??= reading.coordinate;
    if (course != null) {
      final delta = (course - heading + 540) % 360 - 180;
      heading = old == null ? course : (heading + delta * .7 + 360) % 360;
    }
    // Only recent, credible movement can refine ETA. Stationary GPS jitter
    // must not imply travel speed or blow up the duration estimate.
    if (reading.timestamp != null &&
        old != null &&
        elapsed >= 1 &&
        elapsed < 10 &&
        accuracy <= 20 &&
        !offRoute &&
        step > math.max(3, accuracy)) {
      final speed = step / elapsed;
      final reference = route.mode.metersPerMinute / 60;
      if (speed >= reference * .25 && speed <= reference * 2.5) {
        _movingSpeed = _movingSpeed == null
            ? speed
            : _movingSpeed! * .8 + speed * .2;
      }
    }
    arrived =
        arrived ||
        (accuracy <= 30 &&
            fix.along >= progress.length - math.max(20, accuracy) &&
            meters(reading.coordinate, destination) <=
                math.max(10, math.min(15, accuracy)));
    if (arrived) {
      travelled = progress.length;
      offRoute = false;
      status = 'Llegaste a tu destino';
      instruction = 'Has llegado';
      instructionMeters = 0;
    } else if (offRoute) {
      status =
          'Fuera de ruta: regresa al trazado azul (${formatDistance(fix.away)}).';
      instruction = 'Vuelve a la ruta';
      instructionMeters = fix.away;
    } else if (departed) {
      status = 'Comprobando posible desvío · GPS ±${accuracy.round()} m';
    } else {
      // Ignore small jitter; genuine backtracking increases remaining distance.
      final deadband = math.max(1.0, math.min(4.0, accuracy * .3));
      if ((fix.along - travelled).abs() >= deadband) {
        travelled = fix.along;
      }
      status = 'Navegación · ${route.mode.label} · GPS ±${accuracy.round()} m';
      instruction = 'Continúa por la ruta';
      instructionMeters = remainingMeters;
      if (travelled < _roadStart - 1) {
        instruction = 'Ve al inicio de la ruta';
        instructionMeters = _roadStart - travelled;
        status = 'Aproximación al inicio · GPS ±${accuracy.round()} m';
      } else if (travelled > _roadEnd + 1) {
        instruction = 'Dirígete al destino';
        status = 'Aproximación al destino · GPS ±${accuracy.round()} m';
      } else {
        final turn = progress.nextTurn(
          math.max(travelled - 5, _roadStart + .5),
          _roadEnd - .5,
        );
        if (turn != null) {
          instruction = turn.right
              ? 'Gira a la derecha'
              : 'Gira a la izquierda';
          instructionMeters = math.max(0, turn.at - travelled);
        }
      }
    }
    notifyListeners();
  }

  void setFollow(bool value) {
    if (disposed) {
      return;
    }
    follow = value;
    if (value) _cameraRevision++;
    notifyListeners();
  }

  void stop({bool keepStatus = false}) {
    active = false;
    _stale?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (!keepStatus) {
      status = 'Navegación pausada. Pulsa continuar para seguir.';
    }
    if (!disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disposed = true;
    stop();
    super.dispose();
  }
}
