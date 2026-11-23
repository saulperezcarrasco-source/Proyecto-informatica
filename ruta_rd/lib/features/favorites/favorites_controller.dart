import 'package:flutter/foundation.dart';

import 'favorite_repository.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController({FavoriteRepository? repository})
    : repository = repository ?? LocalFavoriteRepository();
  final FavoriteRepository repository;
  List<Favorite> entries = const [];
  bool busy = false, ready = false, invalidData = false, _disposed = false;
  String error = '';
  bool contains(Favorite entry) => entries.any(entry.samePlace);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy || _disposed) return;
    busy = true;
    error = '';
    _changed();
    try {
      final loaded = await repository.load();
      if (_disposed) return;
      entries = List.unmodifiable(loaded);
      ready = true;
      invalidData = false;
    } catch (e) {
      if (_disposed) return;
      ready = false;
      invalidData = e is FormatException;
      error = 'No se pudieron cargar tus favoritos.';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> toggle(Favorite entry) async {
    if (!ready || busy || _disposed) return;
    final next = [...entries];
    if (contains(entry)) {
      next.removeWhere(entry.samePlace);
    } else {
      next.add(entry);
    }
    await _save(next);
  }

  Future<void> reset() => _save([]);
  Future<void> _save(List<Favorite> next) async {
    if (busy || _disposed) return;
    busy = true;
    error = '';
    _changed();
    try {
      await repository.save(next);
      if (_disposed) return;
      entries = List.unmodifiable(next);
      ready = true;
      invalidData = false;
    } catch (_) {
      if (_disposed) return;
      error = 'No se pudo guardar el cambio. Tus favoritos no se modificaron.';
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
