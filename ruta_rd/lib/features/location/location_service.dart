import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/models/models.dart';

class LocationReading {
  const LocationReading(
    this.coordinate,
    this.accuracy, {
    this.approximate = false,
    this.heading,
    this.timestamp,
  });
  final Coordinate coordinate;
  final double accuracy;
  final bool approximate;
  final double? heading;
  final DateTime? timestamp;
  bool get isValid =>
      coordinate.lat.isFinite &&
      coordinate.lon.isFinite &&
      coordinate.lat.abs() <= 90 &&
      coordinate.lon.abs() <= 180 &&
      accuracy.isFinite &&
      accuracy >= 0;
}

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
  invalidPosition,
  outsideCoverage,
}

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
}

abstract class LocationService {
  Future<LocationReading> getCurrentLocation();
  Stream<LocationReading> watch() =>
      Stream.error(const LocationException(LocationFailure.unavailable));
}

/// Injectable native boundary for permission/error tests without GPS hardware.
abstract class GpsPlatform {
  Stream<Position> watch(LocationSettings settings) =>
      Stream.error(const LocationException(LocationFailure.unavailable));
  Future<bool> isEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> position(LocationSettings settings);
  Future<bool> isApproximate();
}

class GeolocatorGpsPlatform implements GpsPlatform {
  @override
  Stream<Position> watch(LocationSettings settings) =>
      Geolocator.getPositionStream(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                forceLocationManager: true,
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 2,
                intervalDuration: const Duration(seconds: 1),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 2,
              ),
      );
  @override
  Future<bool> isEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<Position> position(LocationSettings settings) =>
      Geolocator.getCurrentPosition(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                forceLocationManager: true,
                accuracy: settings.accuracy,
                timeLimit: settings.timeLimit,
                distanceFilter: settings.distanceFilter,
              )
            : settings,
      );
  @override
  Future<bool> isApproximate() async =>
      await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced;
}

class GpsLocationService implements LocationService {
  GpsLocationService({
    GpsPlatform? platform,
    this.timeout = const Duration(seconds: 15),
  }) : platform = platform ?? GeolocatorGpsPlatform();
  final GpsPlatform platform;
  final Duration timeout;
  @override
  Future<LocationReading> getCurrentLocation() async {
    try {
      if (!await platform.isEnabled()) {
        throw const LocationException(LocationFailure.serviceDisabled);
      }
      var permission = await platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await platform.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(LocationFailure.permissionDeniedForever);
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const LocationException(LocationFailure.permissionDenied);
      }
      final p = await platform
          .position(
            LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: timeout,
            ),
          )
          .timeout(timeout);
      final reading = LocationReading(
        Coordinate(lat: p.latitude, lon: p.longitude),
        p.accuracy,
        approximate: await platform.isApproximate(),
        heading: p.speed > .5 && p.heading.isFinite && p.heading >= 0
            ? p.heading
            : null,
        timestamp: p.timestamp,
      );
      if (!reading.isValid) {
        throw const LocationException(LocationFailure.invalidPosition);
      }
      return reading;
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationFailure.permissionDenied);
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  @override
  Stream<LocationReading> watch() async* {
    // Requests permission only when the user explicitly starts navigation.
    final first = await getCurrentLocation();
    yield first;
    try {
      await for (final p in platform.watch(
        const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      )) {
        yield LocationReading(
          Coordinate(lat: p.latitude, lon: p.longitude),
          p.accuracy,
          approximate: first.approximate,
          timestamp: p.timestamp,
          heading: p.speed > .5 && p.heading.isFinite && p.heading >= 0
              ? p.heading
              : null,
        );
      }
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationFailure.permissionDenied);
    }
  }
}
