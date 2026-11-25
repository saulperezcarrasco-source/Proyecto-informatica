import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// One shared native subscription; the last listener releases the GPS.
class NativeGnss {
  static final Stream<Position> positions = const EventChannel('ruta_rd/gnss')
      .receiveBroadcastStream()
      .map((event) {
        final data = Map<Object?, Object?>.from(event as Map);
        double number(String key) => (data[key] as num).toDouble();
        return Position(
          latitude: number('latitude'),
          longitude: number('longitude'),
          accuracy: number('accuracy'),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (data['timestamp'] as num).toInt(),
          ),
          altitude: 0,
          altitudeAccuracy: 0,
          heading: number('heading'),
          headingAccuracy: 0,
          speed: number('speed'),
          speedAccuracy: 0,
        );
      });
}
