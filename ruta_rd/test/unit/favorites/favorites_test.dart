import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruta_rd/features/favorites/favorite_repository.dart';
import 'package:ruta_rd/features/favorites/favorites_controller.dart';

const first = Favorite(placeId: '1', regionId: 'pilot', regionVersion: '1');
const second = Favorite(placeId: '2', regionId: 'pilot', regionVersion: '1');

class FailingRepository implements FavoriteRepository {
  List<Favorite> entries = [first];
  bool fail = true;
  @override
  Future<List<Favorite>> load() async => [...entries];
  @override
  Future<void> save(List<Favorite> next) async {
    if (fail) throw StateError('disco no disponible');
    entries = [...next];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'darkMode': true}));
  test('dos lugares sobreviven a reabrir, preservan región/versión y se puede quitar uno', () async {
    final repository = LocalFavoriteRepository();
    expect(await repository.load(), isEmpty);
    await repository.save([first, second]);
    final reopened = await LocalFavoriteRepository().load();
    expect(reopened.map((entry) => entry.placeId), ['1', '2']);
    expect(
      reopened.every(
        (entry) => entry.regionId == 'pilot' && entry.regionVersion == '1',
      ),
      isTrue,
    );
    await repository.save([reopened.last]);
    expect((await LocalFavoriteRepository().load()).single.placeId, '2');
    expect((await SharedPreferences.getInstance()).getBool('darkMode'), isTrue);
  });
  test('datos inválidos no se borran al cargar; restablecer recupera solo favoritos', () async {
    for (final bad in [
      '{',
      '{"schema":2,"entries":[]}',
      '{"schema":1,"entries":[{"placeId":"1"}]}',
    ]) {
      SharedPreferences.setMockInitialValues({
        LocalFavoriteRepository.storageKey: bad,
        'darkMode': true,
      });
      final controller = FavoritesController();
      await controller.load();
      expect(controller.ready, isFalse);
      expect(controller.invalidData, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString(
          LocalFavoriteRepository.storageKey,
        ),
        bad,
      );
      await controller.reset();
      expect(controller.ready, isTrue);
      expect(controller.error, isEmpty);
      expect(await LocalFavoriteRepository().load(), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getBool('darkMode'),
        isTrue,
      );
      controller.dispose();
    }
  });
  test(
    'fallo de escritura conserva la lista y un reintento guarda el cambio',
    () async {
      final repository = FailingRepository();
      final controller = FavoritesController(repository: repository);
      await controller.load();
      await controller.toggle(second);
      expect(controller.entries.map((entry) => entry.placeId), ['1']);
      expect(controller.error, isNotEmpty);
      repository.fail = false;
      await controller.toggle(second);
      expect(controller.entries.map((entry) => entry.placeId), ['1', '2']);
      expect(controller.error, isEmpty);
      controller.dispose();
    },
  );
  test('IDs iguales en distintas regiones son independientes; actualizar versión no duplica', () async {
    final repository = LocalFavoriteRepository();
    await repository.save([
      first,
      first,
      const Favorite(placeId: '1', regionId: 'other', regionVersion: '2'),
    ]);
    expect(await repository.load(), hasLength(2));
    final controller = FavoritesController(repository: repository);
    await controller.load();
    await controller.toggle(
      const Favorite(placeId: '1', regionId: 'pilot', regionVersion: '2'),
    );
    expect(controller.entries.single.regionId, 'other');
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(
        prefs.getString(LocalFavoriteRepository.storageKey)!,
      )['schema'],
      1,
    );
    controller.dispose();
  });
}
