import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/models/models.dart';

/// Adapts byte-range requests to a local file. It never opens a network socket.
class LocalArchiveClient extends http.BaseClient {
  LocalArchiveClient(this.file);
  final File file;
  static final uri = Uri.parse(
    'http://local-archive.invalid/rd-20261118-v2.pmtiles',
  );
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url != uri || request.method != 'GET') {
      throw StateError('Solo se admite el archivo local');
    }
    final match = RegExp(r'^bytes=(\d+)-(\d+)$')
        .firstMatch(request.headers['range'] ?? '');
    if (match == null) throw StateError('Se requiere un intervalo de bytes');
    final start = int.parse(match[1]!);
    final requestedEnd = int.parse(match[2]!);
    final handle = await file.open();
    try {
      final length = await handle.length();
      if (start >= length || requestedEnd < start) {
        return http.StreamedResponse(const Stream.empty(), 416);
      }
      final end = requestedEnd < length ? requestedEnd : length - 1;
      await handle.setPosition(start);
      final bytes = await handle.read(end - start + 1);
      return http.StreamedResponse(
        Stream.value(bytes),
        206,
        contentLength: bytes.length,
        headers: {'content-range': 'bytes $start-$end/$length'},
      );
    } finally {
      await handle.close();
    }
  }
}

class NationalMapArchive {
  NationalMapArchive._(
    this.provider,
    this.light,
    this.dark,
    this.client,
    this.interiorRings,
  );
  final vt.PmTilesVectorTileProvider provider;
  final vt.Theme light, dark;
  final LocalArchiveClient client;
  final List<List<Coordinate>> interiorRings;
  static Future<NationalMapArchive> open({
    File? archiveFile,
    bool forceCopy = false,
  }) async {
    final File file;
    if (archiveFile != null) {
      file = archiveFile;
    } else {
      final directory = await getApplicationSupportDirectory();
      final manifest = jsonDecode(
        await rootBundle.loadString('assets/national/manifest.json'),
      ) as Map<String, dynamic>;
      final bytes = manifest['bytes'] as int;
      file = File('${directory.path}/rd-20261118-v2.pmtiles');
      if (forceCopy || !await file.exists() || await file.length() != bytes) {
        final data = await rootBundle.load(
          'assets/national/dominican-republic.pmtiles',
        );
        final temporary = File('${file.path}.partial');
        await temporary.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        await temporary.rename(file.path);
      }
      final previous = File('${directory.path}/hispaniola-20261118.pmtiles');
      if (await previous.exists()) await previous.delete();
    }
    final boundary = jsonDecode(
      await rootBundle.loadString('assets/national/dominican-republic.geojson'),
    ) as Map<String, dynamic>;
    final interior = jsonDecode(
      await rootBundle.loadString('assets/national/label-interior.geojson'),
    ) as Map<String, dynamic>;
    Future<vt.Theme> theme(String name) async {
      final bytes = await rootBundle.load('assets/national/$name.json');
      final style = jsonDecode(
        utf8.decode(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        ),
      ) as Map<String, dynamic>;
      for (final layer in style['layers'] as List<dynamic>) {
        // Named POIs come from the indexed national canvas layer. Roads and
        // locality labels remain in the vector basemap at their native zoom.
        if (layer['type'] == 'symbol' && layer['source-layer'] == 'pois') {
          layer['layout'] = {
            ...?(layer['layout'] as Map<String, dynamic>?),
            'visibility': 'none',
          };
        }
        if (layer['type'] == 'symbol') {
          // A mask alone can leave half a foreign label inside the border.
          // Reject labels whose source geometry is outside RD before painting.
          layer['filter'] = [
            'all',
            if (layer['filter'] != null) layer['filter'],
            [
              'any',
              // Inland labels can be accepted by a small conservative polygon.
              // Near the national edge the original 6,871-vertex test remains.
              [
                'all',
                [
                  '>=',
                  ['zoom'],
                  10,
                ],
                ['within', interior['geometry']],
              ],
              ['within', boundary['geometry']],
            ],
          ];
        }
      }
      return const vt.ThemeReader().read(style, id: 'rd-only-$name');
    }

    final client = LocalArchiveClient(file);
    try {
      final provider = await vt.PmTilesVectorTileProvider.open(
        LocalArchiveClient.uri.toString(),
        client: client,
        maxRetries: 0,
      );
      try {
        return NationalMapArchive._(
          provider,
          await theme('light'),
          await theme('dark'),
          client,
          [
            for (final polygon
                in (interior['geometry']['type'] == 'MultiPolygon'
                    ? interior['geometry']['coordinates'] as List
                    : [interior['geometry']['coordinates']]))
              if ((polygon as List).length == 1)
                [
                  for (final p in polygon.first as List)
                    Coordinate(
                      lat: (p[1] as num).toDouble(),
                      lon: (p[0] as num).toDouble(),
                    ),
                ],
          ],
        );
      } catch (_) {
        provider.dispose();
        rethrow;
      }
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  void dispose() {
    provider.dispose();
    client.close();
  }
}
