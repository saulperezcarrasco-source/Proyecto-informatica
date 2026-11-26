import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/location/gps_diagnostics.dart';
import 'package:ruta_rd/features/location/location_service.dart';
import 'package:ruta_rd/features/location/native_gnss.dart';
import 'package:ruta_rd/features/navigation/navigation_controller.dart';

import 'location_test.dart' show FakeGps, samplePosition;
import 'navigation_test.dart' show MovingGps, a, c, route;

class PreciseGps extends FakeGps {
  int satelliteReads = 0;
  @override
  Future<Position> precisePosition(LocationSettings settings) async {
    satelliteReads++;
    return samplePosition();
  }
}

class PermissionPendingGps extends PreciseGps {
  final permissionAnswer = Completer<LocationPermission>();
  @override
  Future<LocationPermission> checkPermission() => permissionAnswer.future;
}

void main() {
  testWidgets(
    'diagnóstico consulta Android y cancela actualización al cerrarse',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        GpsDiagnostics.channel,
        (_) async => {
          'precisePermission': true,
          'gpsEnabled': true,
          'tracking': true,
          'device': 'Equipo de prueba',
          'version': 'test',
          'fixesReceived': 4,
          'fixAgeMillis': 200,
          'accuracyMeters': 8,
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(GpsDiagnostics.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpsDiagnosticsPanel(navigationStatus: () => 'Detenido'),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Equipo de prueba'), findsOneWidget);
      expect(find.text('Copiar diagnóstico'), findsOneWidget);
      expect(find.text('App: Detenido'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  test('ruido GPS detenido no cambia posición, distancia, rumbo ni ETA; movimiento fiable sí', () async {
    final gps = MovingGps();
    final nav = NavigationController(
      route: route,
      destination: c,
      location: gps,
    )..start();
    nav.accept(const LocationReading(a, 10, speed: 0, speedAccuracy: .2));
    final anchor = nav.position;
    final remaining = nav.remainingMeters;
    final heading = nav.heading;
    final eta = nav.remainingMinutes;
    for (final offset in [.00006, -.00004, .00008, -.00001]) {
      nav.accept(
        LocationReading(
          Coordinate(lat: a.lat + offset, lon: a.lon),
          10,
          speed: .1,
          speedAccuracy: .2,
        ),
      );
      expect(nav.position, anchor);
      expect(nav.remainingMeters, remaining);
      expect(nav.heading, heading);
      expect(nav.remainingMinutes, eta);
    }
    nav.accept(
      LocationReading(
        Coordinate(lat: a.lat + .00012, lon: a.lon),
        8,
        speed: 1.5,
        speedAccuracy: .2,
      ),
    );
    expect(nav.remainingMeters, lessThan(remaining - 10));
    nav.dispose();
    await gps.fixes.close();
  });
  test('velocidad sin precisión no se interpreta como detenido', () async {
    final gps = MovingGps();
    final nav = NavigationController(
      route: route,
      destination: c,
      location: gps,
    )..start();
    nav.accept(const LocationReading(a, 5));
    nav.accept(
      LocationReading(Coordinate(lat: a.lat + .00005, lon: a.lon), 5, speed: 0),
    );
    expect(nav.travelled, greaterThan(4));
    final beforeSlowStep = nav.travelled;
    nav.accept(
      LocationReading(
        Coordinate(lat: a.lat + .00008, lon: a.lon),
        5,
        speed: .4,
        speedAccuracy: .1,
      ),
    );
    expect(nav.travelled, greaterThan(beforeSlowStep + 2));
    nav.dispose();
    await gps.fixes.close();
  });
  test('consulta precisa usa satélite; permiso aproximado conserva su consulta compatible', () async {
    final platform = PreciseGps();
    await GpsLocationService(platform: platform).getCurrentLocation();
    expect(platform.satelliteReads, 1);
    expect(platform.positions, 0);
    platform.approximate = true;
    await GpsLocationService(platform: platform).getCurrentLocation();
    expect(platform.satelliteReads, 1);
    expect(platform.positions, 1);
  });
  test(
    'cancelar durante permisos impide iniciar la consulta satelital',
    () async {
      final platform = PermissionPendingGps();
      final service = GpsLocationService(platform: platform);
      final result = service.getCurrentLocation();
      final assertion = expectLater(result, throwsA(isA<LocationException>()));
      await Future<void>.delayed(Duration.zero);
      await service.cancelCurrentLocation();
      platform.permissionAnswer.complete(LocationPermission.whileInUse);
      await assertion;
      expect(platform.satelliteReads, 0);
    },
  );
  test('consulta satelital libera receptor al obtener fix', () async {
    var released = false;
    final source = StreamController<Position>(onCancel: () => released = true);
    final request = SatellitePositionRequest(
      source.stream,
      const Duration(seconds: 1),
    );
    source.add(samplePosition());
    await request.future;
    expect(released, isTrue);
    await source.close();
  });
  test('consulta satelital libera receptor sin fix al agotar espera', () async {
    var released = false;
    final source = StreamController<Position>(onCancel: () => released = true);
    final request = SatellitePositionRequest(
      source.stream,
      const Duration(milliseconds: 10),
    );
    await expectLater(request.future, throwsA(isA<TimeoutException>()));
    expect(released, isTrue);
    await source.close();
  });
  test(
    'cancelar consulta satelital libera receptor e informa cancelación',
    () async {
      var released = false;
      final source = StreamController<Position>(
        onCancel: () => released = true,
      );
      final request = SatellitePositionRequest(
        source.stream,
        const Duration(seconds: 60),
      );
      final assertion = expectLater(request.future, throwsStateError);
      await request.cancel();
      await assertion;
      expect(released, isTrue);
      await source.close();
    },
  );
  test('diagnóstico distingue permiso, GPS apagado, espera y fix sin inventar satélites', () {
    final data = <String, dynamic>{
      'precisePermission': false,
      'gpsEnabled': false,
      'tracking': true,
    };
    expect(GpsDiagnostics(data).explanation, contains('permiso'));
    data['precisePermission'] = true;
    expect(GpsDiagnostics(data).explanation, contains('apagado'));
    data['gpsEnabled'] = true;
    expect(
      GpsDiagnostics(data).report,
      contains('Satélites visibles: sin dato'),
    );
    data.addAll({
      'fixAgeMillis': 10,
      'accuracyMeters': 5,
      'visibleSatellites': 0,
    });
    expect(
      GpsDiagnostics(data).explanation,
      contains('posiciones GPS recientes'),
    );
    data['accuracyMeters'] = 80;
    expect(GpsDiagnostics(data).explanation, contains('insuficiente'));
    expect(GpsDiagnostics(data).report, isNot(contains('latitude')));
  });
}
