import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

import '../../data/national_map_archive.dart';

import '../../core/models/models.dart';
import '../../core/dominican_coverage.dart';
import '../../core/dominican_boundary.dart';
import '../../core/map_visibility.dart';
import '../home/home_controller.dart';
import '../navigation/navigation_controller.dart';
import '../routing/routing_service.dart' show meters;
import 'national_places_layer.dart';
import 'route_endpoint.dart';

class LocalMap extends StatefulWidget {
  const LocalMap({
    super.key,
    required this.controller,
    this.navigation,
    this.height = 380,
  });
  final HomeController controller;
  final NavigationController? navigation;
  final double height;
  @override
  State<LocalMap> createState() => _LocalMapState();
}

/// Do not project/clip 6,871 national-border vertices on every street-level
/// camera frame when no part of the border can possibly be on screen.
class _TerritoryMask extends StatelessWidget {
  const _TerritoryMask({required this.interior, required this.child});
  final List<List<Coordinate>> interior;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final bounds = MapCamera.of(context).visibleBounds;
    final view = RegionBounds(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
    );
    if (interior.any((ring) => viewportInsideRing(view, ring))) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

class _LocalMapState extends State<LocalMap>
    with SingleTickerProviderStateMixin {
  static final islandView = LatLngBounds(
    LatLng(dominicanBounds.south, dominicanBounds.west),
    LatLng(dominicanBounds.north, dominicanBounds.east),
  );
  static final countryHoles = [
    for (final ring in dominicanBoundary)
      [for (final p in ring) LatLng(p.$1, p.$2)],
  ];
  final map = MapController();
  final placeHits = PlaceLabelHits();
  void _placeTapped(Place place) {
    final c = widget.controller;
    final target = c.selection;
    if (widget.navigation == null && target != null) {
      c.selectAndRoute(place, target);
    }
  }

  NationalMapArchive? archive;
  Widget? _baseLayer;
  NationalMapArchive? _baseArchive;
  bool? _baseDark;
  Widget baseLayer(NationalMapArchive data, bool dark) {
    if (_baseLayer == null || _baseArchive != data || _baseDark != dark) {
      _baseArchive = data;
      _baseDark = dark;
      _baseLayer = vt.VectorTileLayer(
        key: const ValueKey('island-basemap'),
        theme: dark ? data.dark : data.light,
        tileProviders: vt.TileProviders({'protomaps': data.provider}),
        diskCacheMaximumSizeInBytes: 0,
        memoryCacheMaxBytes: 24 * 1024 * 1024,
        // Cache rasterized labels instead of shaping/colliding on every pan.
        labelMode: vt.LabelMode.tile,
        rasterCacheMaxBytes: vt.VectorTileLayer.autoRasterCacheBytes,
        tileFadeDuration: Duration.zero,
      );
    }
    return _baseLayer!;
  }

  late Future<NationalMapArchive> national = loadNational();
  Future<NationalMapArchive> loadNational({bool forceCopy = false}) =>
      NationalMapArchive.open(forceCopy: forceCopy).then((value) {
        if (mounted) {
          archive = value;
        } else {
          value.dispose();
        }
        return value;
      });
  RouteResult? previousRoute;
  int previousSelectionVersion = 0;
  Coordinate? _lastNavigationPosition;
  bool _navigationScheduled = false;
  int _lastCameraRevision = -1;
  late final AnimationController _cameraAnimation;
  LatLng? _cameraFrom, _cameraTo;
  double _zoomFrom = 17, _zoomTo = 17;
  @override
  void initState() {
    super.initState();
    _cameraAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          if (!mounted ||
              widget.navigation?.follow != true ||
              _cameraFrom == null ||
              _cameraTo == null) {
            return;
          }
          final t = Curves.easeOutCubic.transform(_cameraAnimation.value);
          map.move(
            LatLng(
              _cameraFrom!.latitude +
                  (_cameraTo!.latitude - _cameraFrom!.latitude) * t,
              _cameraFrom!.longitude +
                  (_cameraTo!.longitude - _cameraFrom!.longitude) * t,
            ),
            _zoomFrom + (_zoomTo - _zoomFrom) * t,
          );
        });
    widget.navigation?.addListener(_navigationChanged);
  }

  void _navigationChanged() {
    final nav = widget.navigation;
    if (!mounted || nav == null || !nav.follow || nav.displayPosition == null) {
      return;
    }
    if (_lastCameraRevision != nav.cameraRevision) {
      _lastCameraRevision = nav.cameraRevision;
      _lastNavigationPosition = null;
    }
    if (nav.displayPosition == _lastNavigationPosition) return;
    final old = _lastNavigationPosition;
    if (!nav.hasReliablePosition && old != null) return;
    // Walking fixes can be only ~1 m apart. Waiting for 2 m makes the camera
    // lag several GPS updates even when a fresh, reliable fix is available.
    if (old != null && meters(old, nav.displayPosition!) < .5) return;
    _lastNavigationPosition = nav.displayPosition;
    if (_navigationScheduled) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      if (mounted && widget.navigation == nav && nav.follow) {
        final target = point(nav.displayPosition!);
        final zoom = math.max(17.0, map.camera.zoom);
        if (old == null ||
            meters(old, nav.displayPosition!) > 1000 ||
            MediaQuery.disableAnimationsOf(context)) {
          _cameraAnimation.stop();
          map.move(target, zoom);
        } else {
          _cameraFrom = map.camera.center;
          _cameraTo = target;
          _zoomFrom = map.camera.zoom;
          _zoomTo = zoom;
          _cameraAnimation.forward(from: 0);
        }
      }
    });
  }

  LatLng point(Coordinate c) => LatLng(c.lat, c.lon);
  @override
  void didUpdateWidget(covariant LocalMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigation != widget.navigation) {
      _lastNavigationPosition = null;
      _lastCameraRevision = -1;
      oldWidget.navigation?.removeListener(_navigationChanged);
      widget.navigation?.addListener(_navigationChanged);
    }
    final route = widget.controller.route;
    final selected = widget.controller.focusedPoint;
    if (selected != null &&
        previousSelectionVersion != widget.controller.selectionVersion &&
        route == null) {
      previousSelectionVersion = widget.controller.selectionVersion;
      final manual = [widget.controller.origin, widget.controller.destination]
          .any(
            (place) =>
                place?.coordinate == selected && place?.category == 'manual',
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A map tap must keep the overview, so the next point can be chosen
        // elsewhere on the island without first undoing an automatic zoom.
        if (!mounted || manual) return;
        final c = widget.controller;
        if (c.origin?.category == 'gps' &&
            identical(selected, c.origin?.coordinate) &&
            (c.accuracy ?? 0) > 100) {
          final radius = (c.accuracy!).clamp(100, 100000);
          final lat = radius / 111320;
          final lon = lat / math.cos(selected.lat * math.pi / 180);
          map.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(
                LatLng(selected.lat - lat, selected.lon - lon),
                LatLng(selected.lat + lat, selected.lon + lon),
              ),
              padding: const EdgeInsets.all(35),
              maxZoom: 17,
            ),
          );
        } else {
          map.move(point(selected), 17);
        }
      });
    }
    if (route != null && route != previousRoute) {
      previousRoute = route;
      final origin = widget.controller.origin!.coordinate;
      final destination = widget.controller.destination!.coordinate;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.controller.route != route) return;
        final points = [
          origin,
          ...route.coordinates,
          destination,
        ].map(point).toList();
        if (points.any((p) => p != points.first)) {
          map.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(35),
            ),
          );
        } else {
          map.move(points.first, 17);
        }
      });
    }
  }

  @override
  void dispose() {
    _cameraAnimation.dispose();
    widget.navigation?.removeListener(_navigationChanged);
    archive?.dispose();
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final route = c.route;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FutureBuilder<NationalMapArchive>(
          future: national,
          builder: (context, snapshot) => FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: islandView.center,
              initialZoom: 6,
              initialCameraFit: CameraFit.bounds(
                bounds: islandView,
                padding: const EdgeInsets.all(12),
              ),
              cameraConstraint: CameraConstraint.containCenter(
                bounds: islandView,
              ),
              minZoom: 5,
              maxZoom: 19,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _cameraAnimation.stop();
                if (hasGesture && widget.navigation?.follow == true) {
                  _lastNavigationPosition = null;
                  widget.navigation?.setFollow(false);
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              backgroundColor: dark
                  ? const Color(0xff172723)
                  : const Color(0xffe8f1ee),
            ),
            children: [
              if (snapshot.hasData) baseLayer(snapshot.data!, dark),
              // Shared border tiles may contain neighbouring-country features.
              // Reveal only the OSM territory of the Dominican Republic.
              _TerritoryMask(
                interior: snapshot.data?.interiorRings ?? const [],
                child: PolygonLayer(
                  polygons: [
                    Polygon(
                      points: const [
                        LatLng(-20, -100),
                        LatLng(60, -100),
                        LatLng(60, -40),
                        LatLng(-20, -40),
                      ],
                      holePointsList: countryHoles,
                      color: dark
                          ? const Color(0xff31353f)
                          : const Color(0xff80deea),
                    ),
                  ],
                ),
              ),
              if (!snapshot.hasData)
                PolygonLayer(
                  polygons: [
                    for (final area in c.region!.areas)
                      Polygon(
                        points: area.map(point).toList(),
                        color: dark
                            ? const Color(0xff253b34)
                            : const Color(0xffd3dfd9),
                        borderColor: dark
                            ? const Color(0xff39584c)
                            : const Color(0xffb8ccc2),
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
              PolylineLayer(
                polylines: [
                  if (!snapshot.hasData)
                    for (final line in c.region!.lines)
                      Polyline(
                        points: line.map(point).toList(),
                        strokeWidth: 3,
                        color: dark
                            ? const Color(0xff7eaa99)
                            : const Color(0xff8aaba0),
                      ),
                  if (route != null)
                    Polyline(
                      points: route.coordinates.map(point).toList(),
                      strokeWidth: 6,
                      color: Colors.blue,
                    ),
                  if (route != null && c.origin != null)
                    Polyline(
                      points: [
                        point(c.origin!.coordinate),
                        point(route.coordinates.first),
                      ],
                      strokeWidth: 3,
                      color: Colors.orange,
                      pattern: const StrokePattern.dotted(),
                    ),
                  if (route != null && c.destination != null)
                    Polyline(
                      points: [
                        point(route.coordinates.last),
                        point(c.destination!.coordinate),
                      ],
                      strokeWidth: 3,
                      color: Colors.orange,
                      pattern: const StrokePattern.dotted(),
                    ),
                ],
              ),
              if (c.origin?.category == 'gps' && c.accuracy != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: point(c.origin!.coordinate),
                      radius: c.accuracy!.clamp(0, 100000).toDouble(),
                      useRadiusInMeter: true,
                      color: Colors.teal.withValues(alpha: .14),
                      borderColor: Colors.teal.withValues(alpha: .5),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              NationalPlacesLayer(
                catalog: c.nationalSearch?.catalog,
                hits: placeHits,
                onPlace: _placeTapped,
                selected: [
                  if (c.origin != null) c.origin!,
                  if (c.destination != null) c.destination!,
                ],
                interactive: widget.navigation == null && c.selection != null,
              ),
              MarkerLayer(
                markers: [
                  if (!snapshot.hasData)
                    for (final p in c.region!.places)
                      Marker(
                        point: point(p.coordinate),
                        width: 8,
                        height: 8,
                        child: const Icon(
                          Icons.circle,
                          size: 5,
                          color: Colors.blueGrey,
                        ),
                      ),
                  if (c.origin != null && widget.navigation == null)
                    Marker(
                      point: point(c.origin!.coordinate),
                      width: 36,
                      height: 36,
                      child: const RouteEndpoint(destination: false, size: 36),
                    ),
                  if (c.destination != null)
                    Marker(
                      point: point(c.destination!.coordinate),
                      width: 36,
                      height: 36,
                      child: const RouteEndpoint(destination: true, size: 36),
                    ),
                ],
              ),
              if (widget.navigation != null)
                ListenableBuilder(
                  listenable: widget.navigation!,
                  builder: (context, _) {
                    final nav = widget.navigation!;
                    if (nav.displayPosition == null) {
                      return const SizedBox.shrink();
                    }
                    final tint = nav.hasReliablePosition
                        ? Colors.blue
                        : Colors.orange;
                    // Keep the reliable arrow centred while the camera catches
                    // up, instead of jumping ahead and sliding back each fix.
                    final markerPoint = nav.follow && nav.hasReliablePosition
                        ? MapCamera.of(context).center
                        : point(nav.displayPosition!);
                    return Stack(
                      children: [
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: markerPoint,
                              radius: nav.accuracy.clamp(0, 200),
                              useRadiusInMeter: true,
                              color: tint.withValues(alpha: .12),
                              borderColor: tint.withValues(alpha: .3),
                              borderStrokeWidth: 1,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: markerPoint,
                              width: 54,
                              height: 54,
                              child: Semantics(
                                key: const ValueKey('navigation-position'),
                                container: true,
                                image: true,
                                label: nav.hasReliablePosition
                                    ? 'Tu posición actual'
                                    : nav.isApproximatePosition
                                    ? 'Tu posición GPS aproximada'
                                    : 'Última posición conocida',
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Transform.rotate(
                                    angle: nav.heading * math.pi / 180,
                                    child: Icon(
                                      Icons.navigation_rounded,
                                      color: tint,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              if (widget.navigation == null && c.selection != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      final named = placeHits.at(details.localPosition);
                      if (named != null) {
                        _placeTapped(named);
                        return;
                      }
                      final p = map.camera.screenOffsetToLatLng(
                        details.localPosition,
                      );
                      c.mapPoint(Coordinate(lat: p.latitude, lon: p.longitude));
                    },
                  ),
                ),
              if (widget.navigation == null)
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FilledButton.tonal(
                      onPressed: () => map.fitCamera(
                        CameraFit.bounds(
                          bounds: islandView,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      child: const Text('Ver toda RD'),
                    ),
                  ),
                ),
              if (snapshot.connectionState != ConnectionState.done)
                Align(
                  alignment: Alignment.center,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Preparando mapa de RD…'),
                    ),
                  ),
                ),
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasError)
                Align(
                  alignment: Alignment.center,
                  child: widget.height < 220
                      ? IconButton.filled(
                          tooltip: 'Reparar mapa de RD',
                          onPressed: () => setState(
                            () => national = loadNational(forceCopy: true),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                        )
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No se pudo abrir el mapa de RD. Puedes reintentar la carga.',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: () => setState(
                                    () => national = loadNational(
                                      forceCopy: true,
                                    ),
                                  ),
                                  child: const Text('Reparar mapa de RD'),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              if (widget.navigation == null)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton.filled(
                      tooltip: 'Ver origen y destino',
                      onPressed: () {
                        final points = [c.origin, c.destination]
                            .whereType<Place>()
                            .map((place) => point(place.coordinate))
                            .toList();
                        if (points.isEmpty) {
                          map.fitCamera(
                            CameraFit.bounds(
                              bounds: islandView,
                              padding: const EdgeInsets.all(12),
                            ),
                          );
                        } else {
                          map.fitCamera(
                            CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(points),
                              padding: const EdgeInsets.all(45),
                              maxZoom: 17,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.center_focus_strong),
                    ),
                  ),
                ),
              if (c.calculating ||
                  (c.routeFailure != null &&
                      c.selection == null &&
                      c.message.isNotEmpty))
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 52),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.calculating) ...[
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Flexible(
                                child: Text(
                                  c.calculating ? 'Trazando ruta…' : c.message,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
