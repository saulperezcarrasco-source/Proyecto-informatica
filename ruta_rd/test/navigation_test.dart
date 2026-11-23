import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';

const a = Coordinate(lat: 18.473, lon: -69.886);
const b = Coordinate(lat: 18.474, lon: -69.886);
const c = Coordinate(lat: 18.474, lon: -69.884);
const route = RouteResult(
  coordinates: [a, b, c],
  distanceMeters: 322,
  estimatedMinutes: 5,
  originApproachMeters: 0,
  destinationApproachMeters: 0,
);

class MovingGps extends LocationService {
  final fixes = StreamController<LocationReading>.broadcast(sync: true);
  @override
  Future<LocationReading> getCurrentLocation() async =>
      const LocationReading(a, 5);
  @override
  Stream<LocationReading> watch() => fixes.stream;
}

void main() {
  test('progreso GPS real proyectado disminuye distancia y mueve flecha sin recalcular ruta', () async {
    final gps = MovingGps();
    final nav = NavigationController(
      route: route,
      destination: c,
      location: gps,
    );
    nav.start();
    gps.fixes.add(const LocationReading(a, 5));
    final first = nav.remainingMeters;
    gps.fixes.add(
      const LocationReading(Coordinate(lat: 18.4735, lon: -69.886), 5),
    );
    expect(nav.remainingMeters, lessThan(first - 45));
    expect(nav.position!.lat, 18.4735);
    expect(nav.instruction, 'Gira a la derecha');
    expect(nav.route, same(route));
    gps.fixes.add(const LocationReading(c, 5));
    expect(nav.arrived, isTrue);
    expect(nav.remainingMeters, 0);
    nav.dispose();
    await gps.fixes.close();
  });
  test(
    'error, señal pobre, punto fuera de RD y posición vieja no inventan avance',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      );
      nav.start();
      gps.fixes.add(const LocationReading(a, 5));
      final remaining = nav.remainingMeters;
      gps.fixes.add(const LocationReading(c, 150));
      expect(nav.arrived, isFalse);
      expect(nav.remainingMeters, remaining);
      gps.fixes.add(
        LocationReading(
          c,
          5,
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      expect(nav.remainingMeters, remaining);
      gps.fixes.add(const LocationReading(Coordinate(lat: 0, lon: 0), 5));
      expect(nav.position!.lat, a.lat);
      gps.fixes.add(
        const LocationReading(Coordinate(lat: 18.476, lon: -69.889), 5),
      );
      expect(nav.offRoute, isTrue);
      expect(nav.remainingMeters, remaining);
      gps.fixes.addError(
        const LocationException(LocationFailure.permissionDenied),
      );
      expect(nav.active, isFalse);
      expect(nav.status, contains('Permiso'));
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test(
    'pausar, reiniciar y destruir cancela seguimiento y descarta eventos',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      );
      nav.start();
      gps.fixes.add(const LocationReading(a, 5));
      nav.stop();
      gps.fixes.add(const LocationReading(c, 5));
      expect(nav.arrived, isFalse);
      nav.start();
      gps.fixes.add(const LocationReading(b, 5));
      expect(nav.position!.lat, closeTo(b.lat, .000001));
      expect(nav.position!.lon, closeTo(b.lon, .000001));
      nav.dispose();
      gps.fixes.add(const LocationReading(c, 5));
      await gps.fixes.close();
    },
  );
  test(
    'proyección admite mismo nodo y conserva metros reales de geometría',
    () {
      final zero = RouteProgress([a]);
      expect(zero.project(a, 0).away, 0);
      final p = RouteProgress([a, b, c]);
      expect(p.length, greaterThan(300));
      expect(p.project(b, 0).along, closeTo(111.2, 1));
    },
  );
}
