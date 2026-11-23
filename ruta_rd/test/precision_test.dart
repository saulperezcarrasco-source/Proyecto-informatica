import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/distance_format.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';
import 'package:ruta_rd/features/search/place_catalog.dart';

import 'navigation_test.dart' show MovingGps, a, b, c, route;

void main() {
  test(
    'rumbo cruza el norte suavemente y ETA usa movimiento GPS fiable',
    () async {
      final gps = MovingGps();
      final nav = NavigationController(
        route: route,
        destination: c,
        location: gps,
      );
      nav.start();
      final now = DateTime.now();
      nav.accept(
        LocationReading(
          a,
          1,
          heading: 359,
          timestamp: now.subtract(const Duration(seconds: 4)),
        ),
      );
      final minutes = nav.remainingMinutes;
      nav.accept(
        LocationReading(
          const Coordinate(lat: 18.47306, lon: -69.886),
          1,
          heading: 1,
          timestamp: now.subtract(const Duration(seconds: 1)),
        ),
      );
      expect(nav.heading < 2 || nav.heading > 358, isTrue);
      expect(nav.remainingMinutes, lessThan(minutes));
      nav.dispose();
      await gps.fixes.close();
    },
  );
  test('distancias cambian a kilómetros desde 1000 metros', () {
    expect(formatDistance(999.9), '999 m');
    expect(formatDistance(1000), '1 km');
    expect(formatDistance(1100), '1.1 km');
    expect(formatDistance(1500), '1.5 km');
    expect(formatDistance(10000), '10 km');
    expect(formatDistance(double.nan), '—');
  });
  test('volver hacia atrás aumenta distancia sin cambiar la ruta', () async {
    final gps = MovingGps();
    final nav = NavigationController(
      route: route,
      destination: c,
      location: gps,
    );
    nav.start();
    nav.accept(const LocationReading(a, 5));
    nav.accept(
      const LocationReading(Coordinate(lat: 18.4737, lon: -69.886), 5),
    );
    final remaining = nav.remainingMeters;
    nav.accept(
      const LocationReading(Coordinate(lat: 18.4733, lon: -69.886), 5),
    );
    expect(nav.remainingMeters, greaterThan(remaining + 40));
    expect(nav.route, same(route));
    nav.dispose();
    await gps.fixes.close();
  });
  test('GPS descarta saltos imposibles y lecturas futuras', () async {
    final gps = MovingGps();
    final nav = NavigationController(
      route: route,
      destination: c,
      location: gps,
    );
    nav.start();
    final now = DateTime.now();
    nav.accept(LocationReading(a, 5, timestamp: now));
    final remaining = nav.remainingMeters;
    nav.accept(
      LocationReading(
        c,
        5,
        timestamp: now.add(const Duration(milliseconds: 100)),
      ),
    );
    expect(nav.arrived, isFalse);
    expect(nav.remainingMeters, remaining);
    nav.accept(
      LocationReading(c, 5, timestamp: now.add(const Duration(minutes: 1))),
    );
    expect(nav.remainingMeters, remaining);
    nav.dispose();
    await gps.fixes.close();
  });
  test('aproximación final también reduce distancia y permite llegada fuera del grafo', () async {
    const end = Coordinate(lat: 18.475, lon: -69.884);
    final gps = MovingGps();
    final nav = NavigationController(
      route: route,
      destination: end,
      location: gps,
    );
    nav.start();
    nav.accept(const LocationReading(c, 5));
    final remaining = nav.remainingMeters;
    nav.accept(
      const LocationReading(Coordinate(lat: 18.4745, lon: -69.884), 5),
    );
    expect(nav.remainingMeters, lessThan(remaining - 45));
    expect(nav.instruction, 'Dirígete al destino');
    nav.accept(const LocationReading(end, 5));
    expect(nav.arrived, isTrue);
    expect(nav.remainingMeters, 0);
    nav.dispose();
    await gps.fixes.close();
  });
  test('índice de segmentos evita recorrer toda una ruta larga', () {
    final points = List.generate(
      2001,
      (i) => Coordinate(lat: 18.473 + i * .0001, lon: -69.886),
    );
    final progress = RouteProgress(points);
    final fix = progress.project(points[900], 0, maxBackward: progress.length);
    expect(fix.along, closeTo(progress.cumulative[900], .01));
    expect(progress.candidatesExamined, lessThan(150));
  });
  test('cruce cercano no salta a un tramo futuro', () {
    const nearStart = Coordinate(lat: 18.473, lon: -69.88599);
    final p = RouteProgress([
      a,
      b,
      c,
      nearStart,
      const Coordinate(lat: 18.472, lon: -69.884),
    ]);
    final fix = p.project(nearStart, 0, maxForward: 40, maxBackward: 40);
    expect(fix.along, lessThan(2));
    expect(fix.away, lessThan(2));
  });
  test(
    'etiquetas cercanas incluyen turismo y negocios, conservan zoom y límite',
    () {
      final catalog = PlaceCatalog([
        const Place(
          id: 'tourism',
          name: 'Museo',
          category: 'turismo',
          coordinate: a,
        ),
        const Place(
          id: 'shop',
          name: 'Colmado',
          category: 'negocio',
          coordinate: b,
        ),
        const Place(
          id: 'street',
          name: 'Calle',
          category: 'calle',
          coordinate: a,
        ),
        const Place(
          id: 'far',
          name: 'Lejos',
          category: 'negocio',
          coordinate: Coordinate(lat: 19.5, lon: -70.7),
        ),
      ]);
      const bounds = RegionBounds(
        south: 18.472,
        west: -69.887,
        north: 18.475,
        east: -69.883,
      );
      expect(catalog.visible(bounds, 13), isEmpty);
      expect(catalog.visible(bounds, 14).map((p) => p.id), ['tourism']);
      expect(catalog.visible(bounds, 17).map((p) => p.id), ['tourism', 'shop']);
      expect(catalog.visible(bounds, 17, limit: 1).length, 1);
    },
  );
}
