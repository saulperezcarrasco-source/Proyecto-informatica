import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/core/travel_mode.dart';
import 'package:ruta_rd/core/dominican_coverage.dart';
import 'package:ruta_rd/features/routing/island_routing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('perfiles nacionales filtrados calculan ida y vuelta con sus propios tiempos', () async {
    const start = Coordinate(lat: 19.4517, lon: -70.697);
    const end = Coordinate(lat: 19.793, lon: -70.688);
    for (final mode in [
      TravelMode.bicycle,
      TravelMode.car,
      TravelMode.motorcycle,
    ]) {
      final service = IslandRoutingService(mode: mode);
      try {
        for (final pair in [(start, end), (end, start)]) {
          final route = await service.calculate(pair.$1, pair.$2);
          expect(route.mode, mode);
          expect(route.distanceMeters, inExclusiveRange(40000, 100000));
          expect(
            route.estimatedMinutes,
            closeTo(mode.minutes(route.distanceMeters), .00001),
          );
          for (var i = 0; i < route.coordinates.length; i += 100) {
            expect(inDominicanRepublic(route.coordinates[i]), isTrue);
          }
          // ignore: avoid_print
          print(
            'NATIONAL_MODE ${mode.name} ${route.distanceMeters.round()}m ${route.estimatedMinutes.toStringAsFixed(1)}min vertices=${route.coordinates.length}',
          );
        }
      } finally {
        service.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
