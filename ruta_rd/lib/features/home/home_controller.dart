import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/dominican_coverage.dart';
import '../../core/travel_mode.dart';
import '../../data/region_repository.dart';
import '../search/search_service.dart';
import '../search/national_search.dart';
import '../routing/routing_service.dart';
import '../routing/island_routing_service.dart';
import '../location/location_service.dart';

enum RegionState { loading, ready, error }

enum Selection { origin, destination }

class HomeController extends ChangeNotifier {
  HomeController({
    RegionRepository? repository,
    LocationService? location,
    this.nationalSearch,
  }) : repository = repository ?? RegionRepository(),
       location = location ?? GpsLocationService();
  final RegionRepository repository;
  final LocationService location;
  final NationalSearch? nationalSearch;
  List<Place> places = [];
  bool nationalSearchReady = false, searchBusy = false;
  String searchNotice = '';
  Timer? _searchDebounce;
  var islandRouting = IslandRoutingService();
  TravelMode travelMode = TravelMode.walking;

  void setTravelMode(TravelMode value) {
    if (disposed || travelMode == value) return;
    travelMode = value;
    _invalidateRoute();
    islandRouting.dispose();
    islandRouting = IslandRoutingService(mode: value);
    message = '';
    changed();
    if (origin != null && destination != null) unawaited(calculate());
  }

  RegionState state = RegionState.loading;
  RegionData? region;
  RoutingService? router;
  List<Place> results = [];
  Place? origin, destination;
  Coordinate? focusedPoint;
  int selectionVersion = 0;
  RouteResult? route;
  RouteFailure? routeFailure;
  double? calculationMilliseconds;
  int _calculationRequest = 0;
  Selection? selection;
  String query = '', message = '';
  bool locating = false, calculating = false, disposed = false;
  double? accuracy;
  bool approximateLocation = false;
  LocationFailure? locationFailure;
  int _locationRequest = 0;
  String get locationMessage => switch (locationFailure) {
    LocationFailure.serviceDisabled =>
      'La ubicación está desactivada. Actívala o elige el origen en el mapa.',
    LocationFailure.permissionDenied => 'No se concedió el permiso. Puedes volver a intentarlo o elegir el origen en el mapa.',
    LocationFailure.permissionDeniedForever => 'El permiso está bloqueado. Abre los permisos de la app o elige el origen en el mapa.',
    LocationFailure.timeout => 'El GPS tardó demasiado. Puedes reintentar o elegir el origen en el mapa.',
    LocationFailure.invalidPosition =>
      'La posición recibida no es válida. Se conserva el origen anterior.',
    LocationFailure.outsideCoverage => 'La ubicación está fuera de República Dominicana. Elige el origen en el mapa; se conserva tu selección anterior.',
    LocationFailure.unavailable => 'No se pudo obtener la ubicación. Puedes reintentar o elegir el origen en el mapa.',
    null => '',
  };
  @override
  void dispose() {
    disposed = true;
    _locationRequest++;
    _searchDebounce?.cancel();
    nationalSearch?.dispose();
    islandRouting.dispose();
    super.dispose();
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> retry() async {
    state = RegionState.loading;
    changed();
    try {
      final data = await repository.loadRegion().timeout(
        const Duration(seconds: 20),
      );
      if (disposed) return;
      router = RoutingService(data.graph, coverage: pilotBounds);
      region = data;
      places = data.places;
      state = RegionState.ready;
      if (nationalSearch != null) unawaited(_loadNational());
    } catch (_) {
      state = RegionState.error;
      message = 'No se pudieron cargar los datos locales.';
    }
    changed();
  }

  void search(String value) {
    query = value;
    results = searchPlaces(region?.places ?? [], value);
    _searchDebounce?.cancel();
    searchBusy = nationalSearchReady && value.trim().length >= 2;
    if (searchBusy) {
      _searchDebounce = Timer(const Duration(milliseconds: 120), () async {
        try {
          final matches = await nationalSearch!.search(value);
          if (disposed || query != value) return;
          final ids = results.map((p) => p.id).toSet();
          results = [
            ...results,
            ...matches.where((p) => !ids.contains(p.id)),
          ].take(20).toList();
          searchNotice = '';
        } catch (_) {
          if (disposed || query != value) return;
          searchNotice =
              'No se pudo consultar el índice nacional. Reintenta la búsqueda.';
        }
        searchBusy = false;
        changed();
      });
    }
    changed();
  }

  Future<void> _loadNational() async {
    try {
      final data = await nationalSearch!.load();
      if (disposed) return;
      places = [...region!.places, ...data];
      nationalSearchReady = true;
      searchNotice = '';
      search(query);
    } catch (_) {
      if (disposed) return;
      searchNotice =
          'Búsqueda nacional no disponible; puedes elegir puntos en el mapa.';
      changed();
    }
  }

  bool select(Place place, Selection target) {
    if (!inDominicanRepublic(place.coordinate)) {
      message = 'Elige un punto dentro de República Dominicana.';
      changed();
      return false;
    }
    if (target == Selection.origin) {
      if (place.category != 'gps') _cancelLocationRequest();
      origin = place;
    } else {
      destination = place;
    }
    _invalidateRoute();
    focusedPoint = place.coordinate;
    selectionVersion++;
    selection = null;
    _searchDebounce?.cancel();
    searchBusy = false;
    query = '';
    results = [];
    if (target == Selection.origin) {
      accuracy = null;
      approximateLocation = false;
    }
    message = '';
    changed();
    return true;
  }

  void mapPoint(Coordinate point) {
    final target = selection;
    if (target == null) return;
    selectAndRoute(
      Place(
        id: 'manual',
        name: 'Punto del mapa',
        category: 'manual',
        coordinate: point,
      ),
      target,
    );
  }

  /// User selections place the marker synchronously, then request the route
  /// automatically once both endpoints exist. Coalesce same-frame edits.
  bool selectAndRoute(Place place, Selection target) {
    if (!select(place, target)) return false;
    final revision = selectionVersion;
    if (origin != null && destination != null) {
      scheduleMicrotask(() {
        if (!disposed && revision == selectionVersion) {
          unawaited(calculate());
        }
      });
    }
    return true;
  }

  void chooseOnMap(Selection target) {
    if (target == Selection.origin) _cancelLocationRequest();
    selection = target;
    message =
        'Toca el mapa para elegir ${target == Selection.origin ? "el origen" : "el destino"}.';
    changed();
  }

  void cancelSelection() {
    selection = null;
    message = '';
    changed();
  }

  void clear() {
    _searchDebounce?.cancel();
    searchBusy = false;
    _cancelLocationRequest();
    origin = destination = null;
    focusedPoint = null;
    _invalidateRoute();
    accuracy = null;
    approximateLocation = false;
    selection = null;
    message = '';
    query = '';
    results = [];
    changed();
  }

  /// Editing one endpoint invalidates its route while retaining the other.
  void clearEndpoint(Selection target) {
    if (target == Selection.origin && (locating || locationFailure != null)) {
      cancelLocation();
    }
    final place = target == Selection.origin ? origin : destination;
    if (place == null) return;
    if (target == Selection.origin) {
      _cancelLocationRequest();
      origin = null;
      accuracy = null;
      approximateLocation = false;
    } else {
      destination = null;
    }
    selectionVersion++;
    _invalidateRoute();
    message = '';
    changed();
  }

  void _invalidateRoute() {
    _calculationRequest++;
    route = null;
    routeFailure = null;
    calculating = false;
    calculationMilliseconds = null;
  }

  void clearRoute() {
    _invalidateRoute();
    message = '';
    changed();
  }

  Future<void> calculate() async {
    if (origin == null ||
        destination == null ||
        router == null ||
        calculating ||
        route != null) {
      return;
    }
    calculating = true;
    route = null;
    routeFailure = null;
    final request = ++_calculationRequest;
    final start = origin!.coordinate, end = destination!.coordinate;
    message = '';
    changed();
    await Future<void>.delayed(Duration.zero);
    if (disposed || request != _calculationRequest) return;
    final stopwatch = Stopwatch()..start();
    try {
      final result =
          travelMode == TravelMode.walking &&
              inCoverage(start) &&
              inCoverage(end)
          ? router!.calculateRoute(start, end)
          : await islandRouting.calculate(start, end);
      if (disposed || request != _calculationRequest) return;
      route = result;
    } on RouteFailure catch (e) {
      if (disposed || request != _calculationRequest) return;
      routeFailure = e;
      message = switch (e) {
        RouteFailure.tooFarFromGraph =>
          'Acerca el mapa y coloca los puntos cerca de una vía para ${travelMode.label.toLowerCase()}.',
        RouteFailure.disconnected =>
          travelMode == TravelMode.walking
              ? 'No hay conexión peatonal entre estos puntos.'
              : 'No hay conexión para ${travelMode.label.toLowerCase()} entre estos puntos.',
        RouteFailure.outsideCoverage =>
          'Elige ambos puntos dentro de República Dominicana.',
        _ => 'No se pudo calcular la ruta con estos datos.',
      };
    }
    stopwatch.stop();
    calculationMilliseconds = stopwatch.elapsedMicroseconds / 1000;
    calculating = false;
    changed();
  }

  Future<void> locate() async {
    if (locating || disposed) return;
    final request = ++_locationRequest;
    locating = true;
    locationFailure = null;
    changed();
    try {
      final reading = await location.getCurrentLocation();
      if (disposed || request != _locationRequest) return;
      if (!reading.isValid) {
        throw const LocationException(LocationFailure.invalidPosition);
      }
      if (!inDominicanRepublic(reading.coordinate)) {
        throw const LocationException(LocationFailure.outsideCoverage);
      }
      if (selectAndRoute(
        Place(
          id: 'gps',
          name: 'Mi ubicación',
          category: 'gps',
          coordinate: reading.coordinate,
        ),
        Selection.origin,
      )) {
        accuracy = reading.accuracy;
        approximateLocation = reading.approximate;
      }
    } on LocationException catch (error) {
      if (disposed || request != _locationRequest) return;
      locationFailure = error.failure;
    } catch (_) {
      if (disposed || request != _locationRequest) return;
      locationFailure = LocationFailure.unavailable;
    }
    if (disposed || request != _locationRequest) return;
    locating = false;
    changed();
  }

  void _cancelLocationRequest() {
    _locationRequest++;
    locating = false;
    locationFailure = null;
  }

  void cancelLocation() {
    _cancelLocationRequest();
    changed();
  }
}
