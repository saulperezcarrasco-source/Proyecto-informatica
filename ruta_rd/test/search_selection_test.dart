import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/search/search_service.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/data/region_repository.dart';

const inside = Coordinate(lat: 18.474, lon: -69.885);
Place place(String id, String name, {List<String> aliases = const []}) => Place(
  id: id,
  name: name,
  category: 'test',
  coordinate: inside,
  aliases: aliases,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ordena exacta, prefijo, parcial y alias con desempate estable', () {
    final places = [
      place('3', 'Otro café'),
      place('2', 'Café central'),
      place('1', 'Café'),
      place('4', 'Alias', aliases: ['café']),
    ];
    expect(searchPlaces(places, '  CAFE ').map((p) => p.id), [
      '4',
      '1',
      '2',
      '3',
    ]);
    expect(searchPlaces(places.reversed.toList(), 'cafe').map((p) => p.id), [
      '4',
      '1',
      '2',
      '3',
    ]);
    expect(normalize('CAFE\u0301   COLÓN'), 'cafe colon');
    expect(searchPlaces(places, '   '), isEmpty);
    expect(searchPlaces(places, 'zzsincoincidencias'), isEmpty);
  });
  test('limita resultados a diez y desempata nombres por id', () {
    final places = List.generate(
      20,
      (i) => place(i.toString().padLeft(2, '0'), 'Café'),
    );
    expect(
      searchPlaces(places.reversed.toList(), 'cafe').map((p) => p.id),
      List.generate(10, (i) => i.toString().padLeft(2, '0')),
    );
  });
  test('el mapa solo coloca A o B tras habilitar su selección explícita', () {
    final c = HomeController();
    addTearDown(c.dispose);
    c.mapPoint(inside);
    expect(c.origin, isNull);
    expect(c.destination, isNull);
    c.chooseOnMap(Selection.origin);
    c.mapPoint(inside);
    expect(c.origin, isNotNull);
    expect(c.destination, isNull);
    final origin = c.origin;
    expect(origin, isNotNull);
    expect(c.selection, isNull);
    c.mapPoint(inside);
    expect(c.destination, isNull);
    c.chooseOnMap(Selection.destination);
    c.mapPoint(inside);
    final destination = c.destination;
    c.chooseOnMap(Selection.origin);
    c.mapPoint(const Coordinate(lat: 0, lon: 0));
    expect(c.origin, origin);
    expect(c.destination, destination);
    expect(c.selection, Selection.origin);
    c.cancelSelection();
    c.mapPoint(inside);
    expect(c.origin, origin);
    c.clear();
    expect(c.origin, isNull);
    expect(c.destination, isNull);
    expect(c.selection, isNull);
    c.mapPoint(inside);
    expect(c.origin, isNull);
    expect(c.destination, isNull);
  });
  test('cambiar origen con destino elegido actualiza el punto enfocado', () {
    final c = HomeController();
    addTearDown(c.dispose);
    c.select(place('d', 'Destino'), Selection.destination);
    final revision = c.selectionVersion;
    const other = Coordinate(lat: 18.475, lon: -69.884);
    c.select(
      const Place(id: 'o', name: 'Origen', category: 'test', coordinate: other),
      Selection.origin,
    );
    expect(c.focusedPoint, other);
    expect(c.selectionVersion, revision + 1);
  });
  test('selecciona puntos de RD y rechaza Haití sin borrar el anterior', () {
    final c = HomeController();
    addTearDown(c.dispose);
    const locations = [
      Coordinate(lat: 19.54878, lon: -71.70829), // Dajabón
      Coordinate(lat: 18.2085, lon: -71.1008), // Barahona
      Coordinate(lat: 19.4517, lon: -70.697), // Santiago
      Coordinate(lat: 18.582, lon: -68.405), // Punta Cana
    ];
    for (final coordinate in locations) {
      c.chooseOnMap(Selection.origin);
      c.mapPoint(coordinate);
      expect(c.origin!.coordinate, coordinate);
      expect(c.selection, isNull);
      c.chooseOnMap(Selection.destination);
      c.mapPoint(locations.last);
      expect(c.destination!.coordinate, locations.last);
      expect(c.origin!.coordinate, coordinate);
    }
    final origin = c.origin;
    for (final invalid in [
      const Coordinate(lat: 20.1, lon: -74.2), // Cuba
      const Coordinate(lat: 18.4, lon: -66.1), // Puerto Rico
      const Coordinate(lat: 18.5944, lon: -72.3074), // Puerto Príncipe
      const Coordinate(lat: 19.15, lon: -72.0), // Haití dentro del rectángulo
      const Coordinate(
        lat: 19.55,
        lon: -71.73,
      ), // Ouanaminthe junto a la frontera
      const Coordinate(lat: double.nan, lon: -70),
      const Coordinate(lat: 19, lon: double.infinity),
    ]) {
      c.chooseOnMap(Selection.origin);
      c.mapPoint(invalid);
      expect(c.origin, origin);
      expect(c.selection, Selection.origin);
    }
  });
  test(
    'calcula una ruta fuera de Ciudad Colonial y conserva sus puntos',
    () async {
      final c = HomeController();
      addTearDown(c.dispose);
      await c.retry();
      expect(c.state, RegionState.ready);
      c.chooseOnMap(Selection.origin);
      c.mapPoint(const Coordinate(lat: 19.4517, lon: -70.697));
      c.chooseOnMap(Selection.destination);
      c.mapPoint(const Coordinate(lat: 19.793, lon: -70.688));
      expect(inCoverage(c.origin!.coordinate), isFalse);
      final origin = c.origin, destination = c.destination;
      await c.calculate();
      expect(c.routeFailure, isNull, reason: c.message);
      expect(c.route, isNotNull, reason: c.message);
      expect(c.route!.distanceMeters, greaterThan(30000));
      expect(c.origin, origin);
      expect(c.destination, destination);
    },
  );
}
