import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/location/native_gnss.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';

import 'navigation_test.dart' show MovingGps, a, b, c, route;

void main() {
  test(
    'seguir mi posición permite recentrar incluso si ya estaba activado',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      )..start();
      nav.accept(const LocationReading(a, 5));
      final first = nav.cameraRevision;
      var changes = 0;
      nav.addListener(() => changes++);
      nav.setFollow(true);
      nav.setFollow(true);
      expect(nav.cameraRevision, first + 2);
      expect(changes, 2);
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test(
    'una pérdida de señal no permite saltar al final de un bucle cercano',
    () async {
      const end = Coordinate(lat: 18.47304, lon: -69.88595);
      const loop = RouteResult(
        coordinates: [a, b, c, Coordinate(lat: 18.473, lon: -69.884), end],
        distanceMeters: 600,
        estimatedMinutes: 8,
        originApproachMeters: 0,
        destinationApproachMeters: 0,
      );
      final gps = MovingGps();
      final nav = NavigationController(
        route: loop,
        destination: end,
        location: gps,
      )..start();
      final time = DateTime.now().subtract(const Duration(seconds: 14));
      nav.accept(LocationReading(a, 5, timestamp: time));
      nav.accept(
        LocationReading(
          end,
          5,
          timestamp: time.add(const Duration(seconds: 18)),
        ),
      );
      expect(nav.arrived, isFalse);
      expect(nav.remainingMeters, greaterThan(400));
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test(
    'giro permanece visible en el cruce y cambia después de pasarlo',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      )..start();
      nav.accept(const LocationReading(a, 5));
      nav.accept(const LocationReading(b, 5));
      expect(nav.instruction, 'Gira a la derecha');
      nav.accept(
        const LocationReading(Coordinate(lat: 18.474, lon: -69.88598), 5),
      );
      expect(nav.instruction, 'Gira a la derecha');
      nav.accept(
        const LocationReading(Coordinate(lat: 18.474, lon: -69.8859), 5),
      );
      expect(nav.instruction, 'Continúa por la ruta');
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test(
    'señal débil muestra posición aproximada sin inventar avance ni llegada',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      )..start();
      nav.accept(const LocationReading(a, 5));
      final remaining = nav.remainingMeters;
      nav.accept(const LocationReading(c, 80));
      expect(nav.position!.lat, a.lat);
      expect(nav.displayPosition, c);
      expect(nav.hasReliablePosition, isFalse);
      expect(nav.isApproximatePosition, isTrue);
      expect(nav.arrived, isFalse);
      expect(nav.remainingMeters, remaining);
      nav.accept(const LocationReading(b, 5));
      expect(nav.hasReliablePosition, isTrue);
      expect(nav.isApproximatePosition, isFalse);
      expect(nav.remainingMeters, lessThan(remaining));
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test(
    'primer fix cerca del origen no salta al final de un recorrido en bucle',
    () async {
      const end = Coordinate(lat: 18.47304, lon: -69.886);
      const loop = RouteResult(
        coordinates: [a, b, c, Coordinate(lat: 18.473, lon: -69.884), end],
        distanceMeters: 600,
        estimatedMinutes: 8,
        originApproachMeters: 0,
        destinationApproachMeters: 0,
      );
      final gps = MovingGps();
      final nav = NavigationController(
        route: loop,
        destination: end,
        location: gps,
      )..start();
      nav.accept(const LocationReading(a, 5));
      expect(nav.arrived, isFalse);
      expect(nav.travelled, lessThan(5));
      expect(nav.remainingMeters, greaterThan(500));
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test(
    'lecturas iguales no reconstruyen la pantalla en cada segundo',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      )..start();
      final start = DateTime.now().subtract(const Duration(seconds: 10));
      nav.accept(LocationReading(a, 5, timestamp: start));
      var notifications = 0;
      nav.addListener(() => notifications++);
      for (var i = 1; i <= 20; i++) {
        nav.accept(
          LocationReading(
            a,
            5,
            timestamp: start.add(Duration(milliseconds: i * 100)),
          ),
        );
      }
      expect(notifications, 0);
      nav.accept(LocationReading(c, 5, timestamp: nav.lastFix));
      expect(nav.arrived, isFalse);
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test(
    'un salto imposible a pie no bloquea la siguiente lectura buena',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      )..start();
      final start = DateTime.now().subtract(const Duration(seconds: 10));
      nav.accept(LocationReading(a, 5, timestamp: start));
      nav.accept(
        LocationReading(b, 5, timestamp: start.add(const Duration(seconds: 1))),
      );
      expect(nav.travelled, 0);
      expect(nav.lastFix, start);
      nav.accept(
        LocationReading(
          const Coordinate(lat: 18.47304, lon: -69.886),
          5,
          timestamp: start.add(const Duration(seconds: 2)),
        ),
      );
      expect(nav.travelled, greaterThan(3));
      expect(nav.hasReliablePosition, isTrue);
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test('desvío necesita confirmación y la llegada no se revoca por ruido posterior', () async {
    final gps = MovingGps();
    final nav = NavigationController(
      route: route,
      destination: c,
      location: gps,
    )..start();
    nav.accept(const LocationReading(a, 5));
    const drift = Coordinate(lat: 18.4731, lon: -69.8864);
    nav.accept(const LocationReading(drift, 5));
    expect(nav.offRoute, isFalse);
    nav.accept(const LocationReading(drift, 5));
    expect(nav.offRoute, isTrue);
    nav.accept(const LocationReading(a, 5));
    expect(nav.offRoute, isFalse);
    nav.accept(const LocationReading(c, 5));
    expect(nav.arrived, isTrue);
    nav.accept(
      const LocationReading(Coordinate(lat: 18.4742, lon: -69.884), 5),
    );
    expect(nav.arrived, isTrue);
    expect(nav.remainingMeters, 0);
    nav.dispose();
    await gps.fixes.close();
  });
  test(
    'reloj incorrecto no descarta un fix fresco basado en tiempo monotónico',
    () {
      final now = DateTime.now();
      final position = NativeGnss.decode({
        'latitude': a.lat,
        'longitude': a.lon,
        'accuracy': 5,
        'timestamp': now.add(const Duration(days: 2)).millisecondsSinceEpoch,
        'ageMillis': 1500,
        'speed': 2,
        'heading': 90,
        'headingAccuracy': 60,
      }, now: now);
      expect(now.difference(position.timestamp).inMilliseconds, 1500);
      expect(position.headingAccuracy, 60);
      expect(position.speedAccuracy, double.infinity);
    },
  );
  test('ventana de progreso y giros usan trabajo acotado en rutas largas', () {
    final points = List.generate(
      20000,
      (i) => Coordinate(lat: 18.473 + i * .000001, lon: -69.886),
    );
    final p = RouteProgress(points);
    final previous = p.cumulative[9000];
    final fix = p.project(
      points[9001],
      previous,
      maxForward: 40,
      maxBackward: 40,
    );
    expect(fix.away, lessThan(1));
    expect(p.segmentsVisited, lessThan(800));
    final turns = RouteProgress(
      List.generate(
        20000,
        (i) => Coordinate(
          lat: 18.473 + i * .00001,
          lon: -69.886 + (i % 2) * .0001,
        ),
      ),
    );
    final turn = turns.nextTurn(turns.length - 100, turns.length);
    expect(turn, isNotNull);
    expect(turns.turnSearchSteps, lessThanOrEqualTo(16));
    debugPrint(
      'NAVIGATION_WORK segments=${p.segmentsVisited}/20000 turnSteps=${turns.turnSearchSteps} turns=${turns.turns.length}',
    );
  });
}
