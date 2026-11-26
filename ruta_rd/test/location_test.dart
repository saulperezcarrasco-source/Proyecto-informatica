import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ruta_rd/core/models/models.dart';
import 'package:ruta_rd/features/home/home_controller.dart';
import 'package:ruta_rd/features/location/location_service.dart';

const manual = Coordinate(lat: 18.474, lon: -69.885);
const gps = Coordinate(lat: 19.4517, lon: -70.697);
Position samplePosition({
  double lat = 19.4517,
  double lon = -70.697,
  double accuracy = 8,
  double speed = 0,
  double heading = 0,
  double headingAccuracy = 0,
}) => Position(
  latitude: lat,
  longitude: lon,
  accuracy: accuracy,
  timestamp: DateTime(2026, 11, 19),
  altitude: 0,
  altitudeAccuracy: 0,
  heading: heading,
  headingAccuracy: headingAccuracy,
  speed: speed,
  speedAccuracy: 0,
);

class FakeGps extends GpsPlatform {
  bool enabled = true, approximate = false;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission granted = LocationPermission.whileInUse;
  int requests = 0, positions = 0;
  int watches = 0;
  Stream<Position> updates = const Stream.empty();
  LocationSettings? watchSettings;
  LocationSettings? settings;
  Future<Position> Function() read = () async => samplePosition();
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return granted;
  }

  @override
  Future<Position> position(LocationSettings value) async {
    positions++;
    settings = value;
    return read();
  }

  @override
  Future<bool> isApproximate() async => approximate;
  @override
  Stream<Position> watch(LocationSettings value) {
    watches++;
    watchSettings = value;
    return updates;
  }
}

class StubLocation extends LocationService {
  StubLocation(this.read);
  Future<LocationReading> Function() read;
  int calls = 0;
  @override
  Future<LocationReading> getCurrentLocation() {
    calls++;
    return read();
  }
}

Matcher failure(LocationFailure value) =>
    isA<LocationException>().having((error) => error.failure, 'failure', value);

void main() {
  test(
    'rumbo nativo exige movimiento y precisión de orientación fiable',
    () async {
      final updates = StreamController<Position>();
      final platform = FakeGps()..updates = updates.stream;
      final headings = <double?>[];
      final subscription = GpsLocationService(platform: platform)
          .watch()
          .listen((fix) => headings.add(fix.heading));
      await Future<void>.delayed(Duration.zero);
      updates.add(samplePosition(speed: 3, heading: 90, headingAccuracy: 100));
      updates.add(samplePosition(speed: 3, heading: 90, headingAccuracy: 10));
      updates.add(samplePosition(speed: .2, heading: 180, headingAccuracy: 10));
      await Future<void>.delayed(Duration.zero);
      expect(headings, [null, 90, null]);
      await subscription.cancel();
      await updates.close();
    },
  );
  test('cancelar mientras se esperan satélites libera el proveedor sin recibir un fix', () async {
    final updates = StreamController<Position>();
    var released = false;
    updates.onCancel = () {
      released = true;
    };
    final native = FakeGps()..updates = updates.stream;
    final subscription = GpsLocationService(platform: native)
        .watch()
        .listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(native.watches, 1);
    await subscription.cancel().timeout(const Duration(seconds: 1));
    expect(released, isTrue);
    await updates.close();
  });
  test('navegación espera el primer fix sin depender de la consulta puntual ni su timeout', () async {
    final updates = StreamController<Position>();
    var cancelled = false;
    updates.onCancel = () => cancelled = true;
    final native = FakeGps()
      ..read = () {
        throw TimeoutException('La consulta puntual no debe ejecutarse');
      }
      ..updates = updates.stream;
    final service = GpsLocationService(
      platform: native,
      timeout: const Duration(milliseconds: 5),
    );
    final readings = <LocationReading>[], errors = <Object>[];
    final subscription = service.watch().listen(
      readings.add,
      onError: errors.add,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(native.positions, 0);
    expect(native.watches, 1);
    expect(errors, isEmpty);
    expect(native.watchSettings!.distanceFilter, 0);
    updates.add(samplePosition(accuracy: 80));
    updates.add(samplePosition(accuracy: 5));
    await Future<void>.delayed(Duration.zero);
    expect(readings.map((r) => r.accuracy), [80, 5]);
    await subscription.cancel();
    expect(cancelled, isTrue);
    await updates.close();
  });
  test(
    'navegación pide ubicación precisa y traduce fallos del GPS nativo',
    () async {
      final native = FakeGps()..approximate = true;
      await expectLater(
        GpsLocationService(platform: native).watch(),
        emitsError(failure(LocationFailure.precisePermissionRequired)),
      );
      expect(native.positions, 0);
      expect(native.watches, 0);
      native.approximate = false;
      for (final entry in {
        'PRECISE_PERMISSION_REQUIRED':
            LocationFailure.precisePermissionRequired,
        'SERVICE_DISABLED': LocationFailure.serviceDisabled,
        'GPS_UNAVAILABLE': LocationFailure.unavailable,
      }.entries) {
        native.updates = Stream.error(PlatformException(code: entry.key));
        await expectLater(
          GpsLocationService(platform: native).watch(),
          emitsError(failure(entry.value)),
        );
      }
    },
  );
  test(
    'GPS desactivado, denegado y bloqueado sin bucles de permisos',
    () async {
      final native = FakeGps()..enabled = false;
      final service = GpsLocationService(platform: native);
      await expectLater(
        service.getCurrentLocation(),
        throwsA(failure(LocationFailure.serviceDisabled)),
      );
      expect(native.requests, 0);
      expect(native.positions, 0);
      native
        ..enabled = true
        ..permission = LocationPermission.denied
        ..granted = LocationPermission.denied;
      await expectLater(
        service.getCurrentLocation(),
        throwsA(failure(LocationFailure.permissionDenied)),
      );
      expect(native.requests, 1);
      expect(native.positions, 0);
      native.permission = LocationPermission.deniedForever;
      await expectLater(
        service.getCurrentLocation(),
        throwsA(failure(LocationFailure.permissionDeniedForever)),
      );
      expect(native.requests, 1);
      expect(native.positions, 0);
    },
  );
  test(
    'permiso puntual, precisión aproximada y tiempo máximo de 15 segundos',
    () async {
      final native = FakeGps()
        ..permission = LocationPermission.denied
        ..approximate = true;
      final result = await GpsLocationService(platform: native)
          .getCurrentLocation();
      expect(native.requests, 1);
      expect(native.positions, 1);
      expect(native.settings!.timeLimit, const Duration(seconds: 15));
      expect(result.coordinate.lat, gps.lat);
      expect(result.accuracy, 8);
      expect(result.approximate, isTrue);
    },
  );
  test(
    'se recupera de tiempo agotado, datos inválidos y error del proveedor',
    () async {
      final native = FakeGps()..read = () => Completer<Position>().future;
      final service = GpsLocationService(
        platform: native,
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        service.getCurrentLocation(),
        throwsA(failure(LocationFailure.timeout)),
      );
      native.read = () async => samplePosition(accuracy: double.nan);
      await expectLater(
        service.getCurrentLocation(),
        throwsA(failure(LocationFailure.invalidPosition)),
      );
      native.read = () async => samplePosition(lat: 91);
      await expectLater(
        service.getCurrentLocation(),
        throwsA(failure(LocationFailure.invalidPosition)),
      );
      native.read = () async => throw StateError('fixture');
      await expectLater(
        service.getCurrentLocation(),
        throwsA(failure(LocationFailure.unavailable)),
      );
      native.read = () async => samplePosition();
      expect((await service.getCurrentLocation()).isValid, isTrue);
    },
  );
  test('consulta solo al pulsar y evita solicitudes simultáneas', () async {
    final result = Completer<LocationReading>();
    final location = StubLocation(() => result.future);
    final c = HomeController(location: location);
    addTearDown(c.dispose);
    expect(location.calls, 0);
    final pending = c.locate();
    await c.locate();
    expect(location.calls, 1);
    expect(c.locating, isTrue);
    result.complete(const LocationReading(gps, 2000, approximate: true));
    await pending;
    expect(c.origin!.category, 'gps');
    expect(c.accuracy, 2000);
    expect(c.approximateLocation, isTrue);
    expect(c.locating, isFalse);
  });
  test('un fallo GPS conserva origen, destino y ruta anteriores', () async {
    final location = StubLocation(
      () async => const LocationReading(Coordinate(lat: 51.5, lon: -.1), 8),
    );
    final c = HomeController(location: location);
    addTearDown(c.dispose);
    c.select(
      const Place(
        id: 'a',
        name: 'Manual',
        category: 'manual',
        coordinate: manual,
      ),
      Selection.origin,
    );
    c.select(
      const Place(
        id: 'b',
        name: 'Destino',
        category: 'manual',
        coordinate: manual,
      ),
      Selection.destination,
    );
    final old = c.route = const RouteResult(
      coordinates: [manual],
      distanceMeters: 0,
      estimatedMinutes: 0,
      originApproachMeters: 0,
      destinationApproachMeters: 0,
    );
    final origin = c.origin, destination = c.destination;
    await c.locate();
    expect(c.locationFailure, LocationFailure.outsideCoverage);
    expect(c.origin, same(origin));
    expect(c.destination, same(destination));
    expect(c.route, same(old));
    for (final error in [
      LocationFailure.permissionDenied,
      LocationFailure.permissionDeniedForever,
      LocationFailure.serviceDisabled,
      LocationFailure.timeout,
      LocationFailure.unavailable,
    ]) {
      location.read = () async => throw LocationException(error);
      await c.locate();
      expect(c.locationFailure, error);
      expect(c.origin, same(origin));
      expect(c.route, same(old));
    }
    location.read = () async => const LocationReading(gps, -1);
    await c.locate();
    expect(c.locationFailure, LocationFailure.invalidPosition);
    expect(c.origin, same(origin));
  });
  test('GPS tardío no sustituye un origen manual ni restaura una selección borrada', () async {
    for (final action in ['map', 'clear', 'edit-origin']) {
      final result = Completer<LocationReading>();
      final c = HomeController(location: StubLocation(() => result.future));
      addTearDown(c.dispose);
      final pending = c.locate();
      if (action == 'clear') {
        c.clear();
      } else if (action == 'edit-origin') {
        c.clearEndpoint(Selection.origin);
      } else {
        c.chooseOnMap(Selection.origin);
        c.mapPoint(manual);
      }
      result.complete(const LocationReading(gps, 5));
      await pending;
      expect(c.locating, isFalse);
      if (action != 'map') {
        expect(c.origin, isNull);
      } else {
        expect(c.origin!.coordinate, manual);
      }
    }
  });
  test(
    'cancelar o destruir durante la consulta descarta éxito y error tardíos',
    () async {
      for (final dispose in [false, true]) {
        final result = Completer<LocationReading>();
        final c = HomeController(location: StubLocation(() => result.future));
        var changes = 0;
        c.addListener(() => changes++);
        final pending = c.locate();
        if (dispose) {
          c.dispose();
        } else {
          c.cancelLocation();
        }
        final previous = changes;
        result.completeError(
          const LocationException(LocationFailure.unavailable),
        );
        await pending;
        expect(changes, previous);
        expect(c.origin, isNull);
        if (!dispose) c.dispose();
      }
    },
  );
}
