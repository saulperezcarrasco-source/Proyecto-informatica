import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/search/national_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('índice nacional offline: ciudades, calles, negocios y turismo fuera del piloto', () async {
    final index = NationalSearch();
    addTearDown(index.dispose);
    final places = await index.load();
    expect(places.length, greaterThan(95118));
    expect(places.any((p) => p.name.endsWith('(sin nombre)')), isTrue);
    expect(places.any((p) => p.category == 'calle'), isTrue);
    for (final q in [
      'Puerto Plata',
      'Santiago',
      '27 de Febrero',
      'Sirena',
      'Salto El Limón',
    ]) {
      final watch = Stopwatch()..start();
      final matches = await index.search(q);
      watch.stop();
      expect(matches, isNotEmpty, reason: q);
      expect(matches.length, lessThanOrEqualTo(15));
      expect(matches.every((p) => p.id.startsWith('rd:')), isTrue);
      // Search time is measured, not asserted against emulator/CI speed.
      // ignore: avoid_print
      print(
        'NATIONAL_SEARCH $q: ${matches.length} results, ${watch.elapsedMilliseconds} ms',
      );
    }
    expect(await index.search('zzzzsinlugareszzzz'), isEmpty);
    for (final query in ['monumento de santiago', 'Santiago monumento']) {
      final matches = await index.search(query);
      expect(matches.first.id, 'rd:way:191967205', reason: query);
    }
    final shops = await index.search('Sirena Santiago');
    expect(shops.any((p) => p.category == 'negocio'), isTrue);
    expect(
      shops.every((p) => p.aliases.any((a) => a.contains('Santiago'))),
      isTrue,
    );
    final monument = places.firstWhere((p) => p.id == 'rd:way:191967205');
    expect(monument.coordinate.lat, closeTo(19.4508, .00001));
    expect(
      index.catalog!
          .visible(
            const RegionBounds(
              south: 19.449,
              west: -70.696,
              north: 19.452,
              east: -70.693,
            ),
            17,
          )
          .any((p) => p.id == monument.id),
      isTrue,
    );
    expect(await index.search('a'), isEmpty);
    final city = await index.search('Puerto Plata');
    expect(city.first.id, 'rd:node:11610553782');
    expect(city.first.name, 'Puerto Plata');
  }, timeout: const Timeout(Duration(seconds: 45)));
}
