import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/dominican_coverage.dart';
import '../location/location_service.dart';
import '../routing/routing_service.dart';
import '../../core/distance_format.dart';

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
  }
  final List<Coordinate> points;
  late final List<double> cumulative;
  final Map<String, List<int>> _cells = {};
  final List<int> _longSegments = [];
  int candidatesExamined = 0;
  double get length => cumulative.last;
  ({double along, double away, int segment, Coordinate point}) project(
    Coordinate p,
    double previous, {
    double? maxForward,
    double? maxBackward,
  }) {
    if (points.length == 1) {
      return (
        along: 0,
        away: meters(p, points.first),
        segment: 0,
        point: points.first,
      );
    }
    final nearby = <int>{..._longSegments};
    final cy = (p.lat * 500).floor(), cx = (p.lon * 500).floor();
    for (var y = cy - 2; y <= cy + 2; y++) {
      for (var x = cx - 2; x <= cx + 2; x++) {
        nearby.addAll(_cells['$y:$x'] ?? const []);
      }
    }
    final candidates = nearby.isEmpty
        ? List<int>.generate(points.length - 1, (i) => i)
        : (nearby.toList()..sort());
    var best = double.infinity, along = previous, segment = 0;
    Coordinate projected = p;
    const scale = 111320.0;
    final cos = math.cos(p.lat * math.pi / 180);
    candidatesExamined = 0;
    for (final i in candidates) {
      if (cumulative[i + 1] < previous - (maxBackward ?? 25) ||
          (maxForward != null && cumulative[i] > previous + maxForward)) {
        continue;
      }
      candidatesExamined++;
      final a = points[i], b = points[i + 1];
      final ax = (a.lon - p.lon) * scale * cos, ay = (a.lat - p.lat) * scale;
      final dx = (b.lon - a.lon) * scale * cos, dy = (b.lat - a.lat) * scale;
      final len = dx * dx + dy * dy;
      final t = len == 0 ? 0.0 : (-(ax * dx + ay * dy) / len).clamp(0.0, 1.0);
      final s = cumulative[i] + t * (cumulative[i + 1] - cumulative[i]);
      if (s < previous - (maxBackward ?? 25) ||
          (maxForward != null && s > previous + maxForward)) {
        continue;
      }
      final away = math.sqrt(
        (ax + t * dx) * (ax + t * dx) + (ay + t * dy) * (ay + t * dy),
      );
      if (away < best) {
        best = away;
        along = s;
        segment = i;
        projected = Coordinate(
          lat: a.lat + t * (b.lat - a.lat),
          lon: a.lon + t * (b.lon - a.lon),
        );
      }
    }
    return (along: along, away: best, segment: segment, point: projected);
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
  DateTime? _trustedTime, lastFix;
  double heading = 0, accuracy = 0, travelled = 0;
  double? _movingSpeed;
  String status = 'Pulsa iniciar para seguir tu ubicación.',
      instruction = 'Continúa por la ruta';
  double instructionMeters = 0;
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
    status = 'Buscando señal GPS…';
    notifyListeners();
    _subscription = location.watch().listen(
      accept,
      onError: (Object error) {
        if (disposed) {
          return;
        }
        status = error is LocationException
            ? switch (error.failure) {
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
          (lastFix == null ||
              DateTime.now().difference(lastFix!).inSeconds > 15)) {
        status = 'Esperando una posición GPS reciente…';
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
    if (age > 15000 ||
        age < -5000 ||
        (lastFix != null && stamp.isBefore(lastFix!))) {
      return;
    }
    if (!inDominicanRepublic(reading.coordinate)) {
      status = 'Tu ubicación está fuera de RD.';
      notifyListeners();
      return;
    }
    lastFix = stamp;
    accuracy = reading.accuracy;
    if (accuracy > 35) {
      status = 'Señal GPS imprecisa: ±${accuracy.round()} m';
      notifyListeners();
      return;
    }
    final step = _trustedRaw == null
        ? 0.0
        : meters(_trustedRaw!, reading.coordinate);
    final elapsed = _trustedTime == null
        ? 0.0
        : stamp.difference(_trustedTime!).inMilliseconds / 1000;
    if (reading.timestamp != null &&
        _trustedRaw != null &&
        elapsed >= 0 &&
        elapsed < 15 &&
        step > 80 * elapsed + accuracy + 20) {
      status = 'Posición GPS inestable. Esperando una lectura fiable…';
      notifyListeners();
      return;
    }
    if (accuracy <= 30 &&
        meters(reading.coordinate, destination) <=
            math.max(10, math.min(15, accuracy))) {
      position = reading.coordinate;
      _trustedRaw = reading.coordinate;
      _trustedTime = stamp;
      arrived = true;
      offRoute = false;
      travelled = progress.length;
      status = 'Llegaste a tu destino';
      instruction = 'Has llegado';
      instructionMeters = 0;
      notifyListeners();
      return;
    }
    final continuous = _trustedRaw != null && elapsed < 15;
    final window = math.max(40.0, step * 2 + accuracy * 2);
    final fix = progress.project(
      reading.coordinate,
      travelled,
      maxForward: continuous ? window : null,
      maxBackward: continuous ? window : progress.length,
    );
    if (!fix.away.isFinite) {
      status = 'Esperando confirmar la posición sobre el recorrido…';
      notifyListeners();
      return;
    }
    final old = _trustedRaw;
    _trustedRaw = reading.coordinate;
    _trustedTime = stamp;
    offRoute = fix.away > math.max(18, accuracy * 1.8);
    position = !offRoute && fix.away <= 12 ? fix.point : reading.coordinate;
    double? course;
    if (reading.heading != null && reading.heading!.isFinite) {
      course = reading.heading! % 360;
    } else if (old != null && step > math.max(2, accuracy * .4)) {
      course = bearing(old, reading.coordinate);
    } else if (old == null && fix.segment + 1 < progress.points.length) {
      course = bearing(
        progress.points[fix.segment],
        progress.points[fix.segment + 1],
      );
    }
    if (course != null) {
      final delta = (course - heading + 540) % 360 - 180;
      heading = old == null ? course : (heading + delta * .55 + 360) % 360;
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
        accuracy <= 30 &&
        meters(reading.coordinate, destination) <=
            math.max(10, math.min(15, accuracy));
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
    } else {
      // Ignore small jitter; genuine backtracking increases remaining distance.
      if (fix.along >= travelled ||
          travelled - fix.along > math.max(3, accuracy * .4)) {
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
        for (
          var i = math.max(1, fix.segment + 1);
          i < progress.points.length - 1;
          i++
        ) {
          final away = progress.cumulative[i] - travelled;
          if (away < 3 ||
              progress.cumulative[i] >= _roadEnd - .5 ||
              progress.cumulative[i] <= _roadStart + .5) {
            continue;
          }
          final a = progress.points[i - 1],
              b = progress.points[i],
              c = progress.points[i + 1];
          if (meters(a, b) < 4 || meters(b, c) < 4) {
            continue;
          }
          final turn = (bearing(b, c) - bearing(a, b) + 540) % 360 - 180;
          if (turn.abs() > 35) {
            instruction = turn > 0
                ? 'Gira a la derecha'
                : 'Gira a la izquierda';
            instructionMeters = away;
            break;
          }
        }
      }
    }
    notifyListeners();
  }

  void setFollow(bool value) {
    if (disposed || follow == value) {
      return;
    }
    follow = value;
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
