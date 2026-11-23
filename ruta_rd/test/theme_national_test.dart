import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruta_rd/core/theme_preferences.dart';
import 'package:ruta_rd/data/national_map_archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('modo oscuro se conserva y se puede volver a claro', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ThemePreferences();
    await first.load();
    expect(first.mode, ThemeMode.system);
    await first.toggle(Brightness.light);
    expect(first.mode, ThemeMode.dark);
    first.dispose();
    final reopened = ThemePreferences();
    await reopened.load();
    expect(reopened.mode, ThemeMode.dark);
    await reopened.toggle(Brightness.dark);
    expect(reopened.mode, ThemeMode.light);
    reopened.dispose();
  });
  test(
    'lector local atiende intervalos y rechaza peticiones remotas',
    () async {
      final dir = await Directory.systemTemp.createTemp('rd-test-');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/bytes');
      await f.writeAsBytes([0, 1, 2, 3, 4]);
      final client = LocalArchiveClient(f);
      addTearDown(client.close);
      final response = await client.get(
        LocalArchiveClient.uri,
        headers: {'range': 'bytes=1-3'},
      );
      expect(response.statusCode, 206);
      expect(response.bodyBytes, [1, 2, 3]);
      expect(
        (await client.get(
          LocalArchiveClient.uri,
          headers: {'range': 'bytes=10-20'},
        )).statusCode,
        416,
      );
      expect(
        () => client.get(
          Uri.parse('https://example.com'),
          headers: {'range': 'bytes=0-1'},
        ),
        throwsStateError,
      );
    },
  );
  test(
    'paquete nacional sirve teselas reales en distintas ciudades sin red',
    () async {
      final archive = await NationalMapArchive.open(
        archiveFile: File('assets/national/dominican-republic.pmtiles'),
      );
      addTearDown(archive.dispose);
      expect(archive.provider.maximumZoom, 15);
      for (final location in [
        [18.4861, -69.9312],
        [19.4517, -70.697],
        [18.582, -68.405],
        [19.793, -70.688],
        [18.2085, -71.1008],
        [19.54878, -71.70829], // Dajabón
      ]) {
        const z = 13;
        final n = 1 << z;
        final lat = location[0] * math.pi / 180;
        final x = ((location[1] + 180) / 360 * n).floor();
        final y =
            ((1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) /
                    2 *
                    n)
                .floor();
        final tile = await archive.provider.load(vt.TileKey(z, x, y));
        expect(
          tile,
          isA<vt.TileResponseData>(),
          reason: '${location[0]}, ${location[1]}',
        );
        expect((tile as vt.TileResponseData).bytes, isNotEmpty);
      }
    },
  );
}
