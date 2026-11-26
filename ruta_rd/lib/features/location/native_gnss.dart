import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// One shared native subscription; the last listener releases the GPS.
class NativeGnss {
  static final Stream<Position> positions = const EventChannel('ruta_rd/gnss')
      .receiveBroadcastStream()
      .map((event) => decode(event));
  static Position decode(Object? event, {DateTime? now}) {
    final data = Map<Object?, Object?>.from(event as Map);
    double number(String key) => (data[key] as num).toDouble();
    return Position(
      latitude: number('latitude'),
      longitude: number('longitude'),
      accuracy: number('accuracy'),
      timestamp: data['ageMillis'] is num
          ? (now ?? DateTime.now()).subtract(
              Duration(
                milliseconds: (data['ageMillis'] as num).toInt().clamp(
                  0,
                  31536000000,
                ),
              ),
            )
          : DateTime.fromMillisecondsSinceEpoch(
              (data['timestamp'] as num).toInt(),
            ),
      altitude: 0,
      altitudeAccuracy: 0,
      heading: number('heading'),
      headingAccuracy:
          (data['headingAccuracy'] is num &&
              (data['headingAccuracy'] as num) >= 0)
          ? number('headingAccuracy')
          : double.infinity,
      speed: number('speed'),
      speedAccuracy:
          (data['speedAccuracy'] is num && (data['speedAccuracy'] as num) >= 0)
          ? number('speedAccuracy')
          : double.infinity,
    );
  }
}

/// A single fresh fix that releases its listener on success, timeout or cancel.
class SatellitePositionRequest {
  SatellitePositionRequest(Stream<Position> source, Duration timeout) {
    _timer = Timer(timeout, () => _finish(error: TimeoutException('GPS')));
    _subscription = source.listen(
      (position) => _finish(position: position),
      onError: (Object error) => _finish(error: error),
      onDone: () => _finish(error: StateError('GPS stream ended')),
    );
    if (_result.isCompleted) unawaited(_subscription?.cancel());
  }
  final _result = Completer<Position>();
  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  Future<Position> get future => _result.future;
  void _finish({Position? position, Object? error}) {
    if (_result.isCompleted) return;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    if (position != null) {
      _result.complete(position);
    } else {
      _result.completeError(error!);
    }
  }

  Future<void> cancel() async {
    _finish(error: StateError('GPS request cancelled'));
    await _subscription?.cancel();
  }
}
