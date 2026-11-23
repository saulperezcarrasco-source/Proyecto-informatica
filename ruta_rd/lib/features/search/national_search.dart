import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import 'search_service.dart';
import 'place_catalog.dart';

/// One persistent worker: decoding, normalization and national searches never
/// sort or scan the national catalogue on the Flutter UI thread.
class NationalSearch {
  Isolate? _worker;
  SendPort? _port;
  bool _disposed = false;
  PlaceCatalog? catalog;

  Future<List<Place>> load() async {
    final data = await rootBundle.load('assets/search/places.rds');
    final reply = ReceivePort();
    try {
      final worker = await Isolate.spawn(_run, [
        reply.sendPort,
        TransferableTypedData.fromList([
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ]),
      ]);
      if (_disposed) {
        worker.kill(priority: Isolate.immediate);
        return [];
      }
      _worker = worker;
      final initial =
          await reply.first.timeout(const Duration(seconds: 25)) as List;
      _port = initial[0] as SendPort;
      catalog = initial[1] as PlaceCatalog;
      return catalog!.places;
    } finally {
      reply.close();
    }
  }

  Future<List<Place>> search(String query) async {
    if (_disposed || _port == null) return [];
    final reply = ReceivePort();
    try {
      _port!.send([reply.sendPort, query]);
      return (await reply.first.timeout(const Duration(seconds: 5)) as List)
          .cast<Place>();
    } finally {
      reply.close();
    }
  }

  void dispose() {
    _disposed = true;
    _worker?.kill(priority: Isolate.immediate);
    _port = null;
  }

  static void _run(List message) {
    final bytes = (message[1] as TransferableTypedData)
        .materialize()
        .asUint8List();
    final rows = jsonDecode(utf8.decode(gzip.decode(bytes))) as List;
    final places = rows
        .map(
          (p) => Place(
            id: p[0],
            name: p[1],
            category: p[2],
            coordinate: Coordinate(
              lat: (p[3] as num).toDouble(),
              lon: (p[4] as num).toDouble(),
            ),
            aliases: (p[5] as List).cast<String>(),
          ),
        )
        .toList();
    final terms = [
      for (final p in places) [normalize(p.name), ...p.aliases.map(normalize)],
    ];
    final port = ReceivePort();
    (message[0] as SendPort).send([port.sendPort, PlaceCatalog(places)]);
    port.listen((dynamic request) {
      final q = normalize(request[1] as String);
      final words = searchWords(q);
      final matches = <(int, int, int)>[];
      if (q.length >= 2) {
        for (var i = 0; i < places.length; i++) {
          final rank = nationalMatchRank(terms[i], q, words);
          if (rank < 4) {
            matches.add((rank, nationalMatchRank([terms[i][0]], q, words), i));
          }
        }
        matches.sort((a, b) {
          final r = a.$1.compareTo(b.$1);
          if (r != 0) return r;
          final primary = a.$2.compareTo(b.$2);
          if (primary != 0) return primary;
          final name = terms[a.$3][0].compareTo(terms[b.$3][0]);
          return name != 0 ? name : places[a.$3].id.compareTo(places[b.$3].id);
        });
      }
      final used = <String>{};
      final result = <Place>[];
      for (final match in matches) {
        final p = places[match.$3];
        // OSM roads are split into ways: show a name at most once per ~1 km.
        final key =
            '${normalize(p.name)}:${(p.coordinate.lat * 100).round()}:${(p.coordinate.lon * 100).round()}';
        if (used.add(key)) result.add(p);
        if (result.length == 15) break;
      }
      (request[0] as SendPort).send(result);
    });
  }
}
