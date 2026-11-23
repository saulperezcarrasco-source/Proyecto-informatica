import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Favorite {
  const Favorite({
    required this.placeId,
    required this.regionId,
    required this.regionVersion,
  });
  final String placeId, regionId, regionVersion;
  bool samePlace(Favorite other) =>
      placeId == other.placeId && regionId == other.regionId;
  Map<String, String> toJson() => {
    'placeId': placeId,
    'regionId': regionId,
    'regionVersion': regionVersion,
  };
  factory Favorite.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Favorito inválido');
    }
    String field(String key) {
      final entry = value[key];
      if (entry is! String || entry.trim().isEmpty) {
        throw const FormatException('Referencia inválida');
      }
      return entry;
    }

    return Favorite(
      placeId: field('placeId'),
      regionId: field('regionId'),
      regionVersion: field('regionVersion'),
    );
  }
}

abstract class FavoriteRepository {
  Future<List<Favorite>> load();
  Future<void> save(List<Favorite> entries);
}

class LocalFavoriteRepository implements FavoriteRepository {
  static const storageKey = 'ruta_rd.favorites.v1';
  @override
  Future<List<Favorite>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.get(storageKey);
    if (value == null) return [];
    if (value is! String) {
      throw const FormatException('Almacenamiento inválido');
    }
    final json = jsonDecode(value);
    if (json is! Map<String, dynamic> ||
        json['schema'] != 1 ||
        json['entries'] is! List) {
      throw const FormatException('Formato de favoritos desconocido');
    }
    final entries = <Favorite>[];
    for (final item in json['entries'] as List) {
      final entry = Favorite.fromJson(item);
      if (!entries.any(entry.samePlace)) entries.add(entry);
    }
    return entries;
  }

  @override
  Future<void> save(List<Favorite> entries) async {
    final preferences = await SharedPreferences.getInstance();
    final ok = await preferences.setString(
      storageKey,
      jsonEncode({
        'schema': 1,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      }),
    );
    if (!ok) throw StateError('No se pudo persistir favoritos');
  }
}
