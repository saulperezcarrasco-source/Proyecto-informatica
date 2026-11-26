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
