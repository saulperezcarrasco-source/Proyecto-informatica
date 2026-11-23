import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/features/map/route_endpoint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/data/region_repository.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/home/home_screen.dart';
import 'package:ruta_rd/features/routing/routing_service.dart';
import 'package:ruta_rd/features/search/search_service.dart';
import 'package:ruta_rd/features/location/location_service.dart';

class FakeLocation extends LocationService {
  @override
  Future<LocationReading> getCurrentLocation() async =>
      const LocationReading(Coordinate(lat: 18.474, lon: -69.885), 5);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  late RegionData data;
  setUpAll(() async {
    data = await RegionRepository().loadRegion();
  });
  test('los assets tienen referencias, coordenadas y pesos válidos', () {
    expect(data.graph.nodes, isNotEmpty);
    expect(data.places, isNotEmpty);
    expect(() => RoutingService(data.graph), returnsNormally);
  });
  test('búsqueda normaliza tildes, espacios y mayúsculas', () {
    const p = Place(
      id: '1',
      name: 'Café Colón',
      category: 'test',
      coordinate: Coordinate(lat: 18.474, lon: -69.885),
    );
    expect(searchPlaces([p], '  CAFE   COLON ').single.id, '1');
    expect(searchPlaces([p], ''), isEmpty);
  });
  test('GPS reemplaza origen válido y Limpiar borra el estado', () async {
    final c = HomeController(location: FakeLocation())
      ..region = data
      ..router = RoutingService(data.graph)
      ..state = RegionState.ready;
    addTearDown(c.dispose);
    await c.locate();
    expect(c.origin!.name, 'Mi ubicación');
    expect(c.accuracy, 5);
    c.clear();
    expect(c.origin, isNull);
    expect(c.route, isNull);
    expect(c.query, isEmpty);
  });
  for (final size in [const Size(320, 480), const Size(640, 320)]) {
    testWidgets('interfaz funcional con texto grande en $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = HomeController()
        ..region = data
        ..router = RoutingService(data.graph)
        ..state = RegionState.ready;
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2),
            ),
            child: HomeScreen(controller: c),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test('Dijkstra respeta pesos y dirección', () {
    const a = Coordinate(lat: 18.474, lon: -69.885),
        b = Coordinate(lat: 18.4741, lon: -69.885),
        c = Coordinate(lat: 18.4742, lon: -69.885);
    final router = RoutingService(
      const RoutingGraph(
        nodes: [
          GraphNode(id: 'a', coordinate: a),
          GraphNode(id: 'b', coordinate: b),
          GraphNode(id: 'c', coordinate: c),
        ],
        edges: [
          GraphEdge(from: 'a', to: 'b', distanceMeters: 4),
          GraphEdge(from: 'b', to: 'c', distanceMeters: 5),
          GraphEdge(from: 'a', to: 'c', distanceMeters: 20),
        ],
      ),
    );
    expect(router.calculateRoute(a, c).distanceMeters, 9);
    expect(
      () => router.calculateRoute(c, a),
      throwsA(RouteFailure.disconnected),
    );
    expect(router.calculateRoute(a, a).distanceMeters, 0);
    expect(
      () => router.calculateRoute(const Coordinate(lat: 0, lon: 0), c),
      throwsA(RouteFailure.tooFarFromGraph),
    );
  });
  test(
    'cambiar puntos limpia ruta y rechaza puntos fuera de cobertura',
    () async {
      final controller = HomeController()
        ..region = data
        ..router = RoutingService(data.graph)
        ..state = RegionState.ready;
      addTearDown(controller.dispose);
      final n = data.graph.nodes.first;
      final place = Place(
        id: '1',
        name: 'Origen',
        category: 'test',
        coordinate: n.coordinate,
      );
      controller.select(place, Selection.origin);
      controller.select(place, Selection.destination);
      await controller.calculate();
      expect(controller.route, isNotNull);
      controller.select(place, Selection.destination);
      expect(controller.route, isNull);
      expect(
        controller.select(
          const Place(
            id: 'x',
            name: 'Fuera',
            category: 'test',
            coordinate: Coordinate(lat: 0, lon: 0),
          ),
          Selection.origin,
        ),
        isFalse,
      );
      expect(controller.origin, place);
    },
  );
  testWidgets('buscar, elegir y limpiar funciona en la pantalla', (
    tester,
  ) async {
    final controller = HomeController()
      ..region = data
      ..router = RoutingService(data.graph)
      ..state = RegionState.ready;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    final originField = find.byKey(const ValueKey('origin-search'));
    final destinationField = find.byKey(const ValueKey('destination-search'));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Para trazar una ruta personalizada:'), findsNothing);
    final a = data.places.firstWhere((p) => p.name == 'Café Conde de Peñalba');
    final b = data.places.firstWhere((p) => p.name == 'Café La Moricette');
    await tester.enterText(originField, a.name);
    await tester.pumpAndSettle();
    expect(find.text('Usar como origen'), findsWidgets);
    await tester.tap(find.text('Usar como origen').first);
    await tester.pumpAndSettle();
    expect(controller.origin, isNotNull);
    expect(tester.widget<TextField>(originField).controller!.text, a.name);
    await tester.enterText(destinationField, b.name);
    await tester.pumpAndSettle();
    expect(find.text('Usar como origen'), findsNothing);
    await tester.tap(find.text('Usar como destino').first);
    await tester.pumpAndSettle();
    expect(controller.destination, b);
    expect(controller.route, isNotNull);
    // Editing A invalidates its old route, retaining B and its displayed name.
    await tester.enterText(originField, 'zzsincoincidencias');
    await tester.pumpAndSettle();
    expect(controller.origin, isNull);
    expect(controller.route, isNull);
    expect(controller.destination, b);
    expect(tester.widget<TextField>(destinationField).controller!.text, b.name);
    await tester.tap(find.byTooltip('Borrar origen'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(originField).controller!.text, isEmpty);
    // Selections made on the map/GPS/favorites must update the same inputs.
    controller.selectAndRoute(a, Selection.origin);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(originField).controller!.text, a.name);
    await tester.ensureVisible(find.text('Limpiar'));
    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(controller.origin, isNull);
    expect(controller.query, isEmpty);
    expect(tester.widget<TextField>(originField).controller!.text, isEmpty);
    expect(
      tester.widget<TextField>(destinationField).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'el punto aparece en el primer frame sin mover ni recrear el mapa',
    (tester) async {
      final c = HomeController()
        ..region = data
        ..router = RoutingService(data.graph)
        ..state = RegionState.ready;
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(controller: c)));
      final mapFinder = find.byType(FlutterMap);
      await tester.ensureVisible(mapFinder);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(mapFinder) + const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(c.origin, isNull);
      expect(c.destination, isNull);
      final element = tester.element(mapFinder);
      final top = tester.getTopLeft(mapFinder);
      final camera = tester.widget<FlutterMap>(mapFinder).mapController!.camera;
      c.chooseOnMap(Selection.origin);
      await tester.pump();
      expect(tester.element(mapFinder), same(element));
      expect(tester.getTopLeft(mapFinder), top);
      // The unit environment has no native path_provider, so its repair card
      // covers the center. Tap unobstructed cartography above that card.
      await tester.tapAt(tester.getCenter(mapFinder) + const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        c.origin,
        isNotNull,
        reason:
            'Selección ${c.selection}: ${c.message}; centro ${camera.center}',
      );
      expect(
        find.descendant(
          of: mapFinder,
          matching: find.byWidgetPredicate(
            (w) => w is RouteEndpoint && !w.destination,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.element(mapFinder), same(element));
      expect(tester.getTopLeft(mapFinder), top);
      final after = tester.widget<FlutterMap>(mapFinder).mapController!.camera;
      expect(after.center, camera.center);
      expect(after.zoom, camera.zoom);
      expect(tester.takeException(), isNull);
    },
  );
}
