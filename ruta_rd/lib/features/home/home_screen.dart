import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/models/models.dart';
import '../../core/distance_format.dart';
import '../../core/brand_logo.dart';
import '../../core/travel_mode.dart';
import '../../core/map_credits.dart';
import '../../core/theme_preferences.dart';
import 'home_controller.dart';
import 'planning_endpoints.dart';
import '../map/local_map.dart';
import '../location/location_service.dart';
import '../favorites/favorite_repository.dart';
import '../favorites/favorites_controller.dart';
import '../favorites/favorites_panel.dart';
import '../search/national_search.dart';
import '../navigation/navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.controller,
    this.favoritesController,
    this.searchPreview = false,
  });
  final HomeController? controller;
  final FavoritesController? favoritesController;
  final bool searchPreview;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController controller;
  late final FavoritesController favorites;
  final originText = TextEditingController();
  final destinationText = TextEditingController();
  Selection searchTarget = Selection.origin;
  Selection? editingTarget;
  Place? shownOrigin, shownDestination;
  @override
  void initState() {
    super.initState();
    controller =
        widget.controller ?? HomeController(nationalSearch: NationalSearch());
    favorites = widget.favoritesController ?? FavoritesController();
    controller.addListener(syncEndpoints);
    syncEndpoints();
    unawaited(favorites.load());
    if (controller.region == null) controller.retry();
  }

  @override
  void dispose() {
    controller.removeListener(syncEndpoints);
    originText.dispose();
    destinationText.dispose();
    if (widget.controller == null) controller.dispose();
    if (widget.favoritesController == null) favorites.dispose();
    super.dispose();
  }

  void select(Place place, Selection target) {
    editingTarget = null;
    controller.selectAndRoute(place, target);
    FocusScope.of(context).unfocus();
  }

  void syncEndpoints() {
    void sync(Selection target, Place? before, Place? after) {
      if (!identical(before, after) &&
          (after != null || editingTarget != target)) {
        final field = target == Selection.origin ? originText : destinationText;
        field.text = after?.name ?? '';
      }
    }

    sync(Selection.origin, shownOrigin, controller.origin);
    sync(Selection.destination, shownDestination, controller.destination);
    shownOrigin = controller.origin;
    shownDestination = controller.destination;
  }

  void searchEndpoint(Selection target, String value) {
    searchTarget = target;
    editingTarget = target;
    if (controller.selection != null) controller.cancelSelection();
    controller.clearEndpoint(target);
    controller.search(value);
  }

  void activateSearch(Selection target) {
    searchTarget = target;
    final field = target == Selection.origin ? originText : destinationText;
    final place = target == Selection.origin
        ? controller.origin
        : controller.destination;
    controller.search(field.text == place?.name ? '' : field.text);
  }

  void chooseMap(Selection target) {
    FocusScope.of(context).unfocus();
    editingTarget = null;
    final field = target == Selection.origin ? originText : destinationText;
    field.text =
        (target == Selection.origin
                ? controller.origin
                : controller.destination)
            ?.name ??
        '';
    controller.search('');
    if (controller.selection == target) {
      controller.cancelSelection();
    } else {
      controller.chooseOnMap(target);
    }
  }

  void openFavorites() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Favoritos', style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, child) => FavoritesPanel(
                    controller: favorites,
                    region: controller.region!.manifest,
                    places: controller.places.isEmpty
                        ? controller.region!.places
                        : controller.places,
                    initiallyExpanded: true,
                    showToggle: false,
                    onOrigin: (place) {
                      Navigator.pop(sheet);
                      select(place, Selection.origin);
                    },
                    onDestination: (place) {
                      Navigator.pop(sheet);
                      select(place, Selection.destination);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void routeDetails() {
    final c = controller, route = controller.route;
    if (route == null) return;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Detalles de ruta'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Origen: ${c.origin!.name}'),
              const SizedBox(height: 8),
              Text('Destino: ${c.destination!.name}'),
              const SizedBox(height: 16),
              Text(
                '${formatDistance(route.distanceMeters)} · ${route.estimatedMinutes.ceil()} min aprox. · ${route.mode.label}',
              ),
              const SizedBox(height: 12),
              Text(
                'Aproximación al origen: ${formatDistance(route.originApproachMeters)}. Al destino: ${formatDistance(route.destinationApproachMeters)}.',
              ),
              const Text('Las líneas naranjas son accesos no verificados.'),
              if (c.travelMode != TravelMode.walking)
                const Text(
                  'Tiempo orientativo por velocidad media; sin tráfico en tiempo real.',
                ),
              if (route.coordinates.length == 1)
                Text(
                  c.origin!.coordinate.lat == c.destination!.coordinate.lat &&
                          c.origin!.coordinate.lon ==
                              c.destination!.coordinate.lon
                      ? 'Origen y destino coinciden: no necesitas desplazarte.'
                      : 'Ambos puntos se ajustan al mismo nodo. El recorrido sobre calles es de 0 m; las aproximaciones se indican por separado.',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              c.clearRoute();
            },
            child: const Text('Borrar ruta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  IconData modeIcon(TravelMode mode) => switch (mode) {
    TravelMode.walking => Icons.directions_walk_rounded,
    TravelMode.bicycle => Icons.directions_bike_rounded,
    TravelMode.car => Icons.directions_car_rounded,
    TravelMode.motorcycle => Icons.two_wheeler_rounded,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller, scheme = Theme.of(context).colorScheme;
          if (c.state == RegionState.loading) return const BrandLoading();
          if (c.state == RegionState.error) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ruta RD Offline',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(c.message, textAlign: TextAlign.center),
                    FilledButton(
                      onPressed: c.retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/brand/ruta_symbol.png',
                          width: 34,
                          height: 34,
                          cacheWidth: 102,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ruta RD',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mi ubicación',
                          onPressed: c.locating ? null : c.locate,
                          icon: c.locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                        ),
                        IconButton(
                          key: const ValueKey('favorites-panel-toggle'),
                          tooltip: 'Favoritos',
                          onPressed: openFavorites,
                          icon: const Icon(Icons.star_border_rounded),
                        ),
                        if (ThemePreferencesScope.of(context) != null)
                          IconButton(
                            tooltip:
                                Theme.of(context).brightness == Brightness.dark
                                ? 'Activar modo claro'
                                : 'Activar modo oscuro',
                            onPressed: () =>
                                ThemePreferencesScope.of(context)!
                                    .toggle(Theme.of(context).brightness),
                            icon: Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PlanningEndpoints(
                      controller: c,
                      originText: originText,
                      destinationText: destinationText,
                      onSearch: searchEndpoint,
                      onActivate: activateSearch,
                      onChooseMap: chooseMap,
                    ),
                    if (c.searchBusy)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Buscando en República Dominicana…'),
                      ),
                    if (c.searchNotice.isNotEmpty) Text(c.searchNotice),
                    if (c.query.trim().isNotEmpty &&
                        c.results.isEmpty &&
                        !c.searchBusy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No se encontraron lugares.'),
                      ),
                    if (c.results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Material(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            children: [
                              for (final place in c.results)
                                ListTile(
                                  title: Text(place.name),
                                  onTap: () => select(place, searchTarget),
                                  trailing: FavoriteButton(
                                    controller: favorites,
                                    entry: Favorite(
                                      placeId: place.id,
                                      regionId: place.id.startsWith('rd:')
                                          ? 'dominican-search'
                                          : c.region!.manifest.id,
                                      regionVersion: place.id.startsWith('rd:')
                                          ? '2026-11-18'
                                          : c.region!.manifest.version,
                                    ),
                                  ),
                                  subtitle: Wrap(
                                    spacing: 8,
                                    children: [
                                      if (searchTarget == Selection.origin)
                                        TextButton(
                                          onPressed: () =>
                                              select(place, Selection.origin),
                                          child: const Text('Usar como origen'),
                                        ),
                                      if (searchTarget == Selection.destination)
                                        TextButton(
                                          onPressed: () => select(
                                            place,
                                            Selection.destination,
                                          ),
                                          child: const Text(
                                            'Usar como destino',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final mode in TravelMode.values)
                          ChoiceChip(
                            key: ValueKey('travel-${mode.assetName}'),
                            showCheckmark: false,
                            avatar: Icon(modeIcon(mode), size: 18),
                            label: Text(mode.label),
                            selected: c.travelMode == mode,
                            onSelected: (_) {
                              FocusScope.of(context).unfocus();
                              c.setTravelMode(mode);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: c.calculating
                                ? null
                                : c.route != null
                                ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => NavigationScreen(home: c),
                                    ),
                                  )
                                : c.origin != null && c.destination != null
                                ? c.calculate
                                : null,
                            icon: Icon(
                              c.route != null
                                  ? Icons.navigation_rounded
                                  : Icons.route_rounded,
                            ),
                            label: Text(
                              c.calculating
                                  ? 'Calculando…'
                                  : c.route != null
                                  ? 'Iniciar navegación'
                                  : 'Calcular ruta',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            editingTarget = null;
                            originText.clear();
                            destinationText.clear();
                            c.clear();
                          },
                          child: const Text('Limpiar'),
                        ),
                        if (c.route != null)
                          IconButton(
                            tooltip: 'Detalles de ruta',
                            onPressed: routeDetails,
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                      ],
                    ),
                    if (c.route != null)
                      Padding(
                        key: const ValueKey('route-summary'),
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${formatDistance(c.route!.distanceMeters)} · ${c.route!.estimatedMinutes.ceil()} min aprox. · ${c.route!.mode.label}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (c.locating)
                      TextButton(
                        onPressed: c.cancelLocation,
                        child: const Text('Cancelar GPS'),
                      ),
                    if (c.accuracy != null && c.origin?.category == 'gps')
                      Text(
                        'Precisión de ubicación: ±${c.accuracy!.round()} m${c.approximateLocation ? " · Ubicación aproximada" : ""}',
                      ),
                    if (c.locationFailure != null) Text(c.locationMessage),
                    if (c.locationFailure == LocationFailure.serviceDisabled)
                      TextButton(
                        onPressed: Geolocator.openLocationSettings,
                        child: const Text('Activar ubicación'),
                      ),
                    if (c.locationFailure ==
                        LocationFailure.permissionDeniedForever)
                      TextButton(
                        onPressed: Geolocator.openAppSettings,
                        child: const Text('Abrir permisos de la app'),
                      ),
                    if (c.message.isNotEmpty && c.selection == null)
                      Text(c.message, semanticsLabel: c.message),
                    const MapCredits(),
                    LocalMap(
                      key: const ValueKey('local-map'),
                      controller: c,
                      height: math.max(
                        380,
                        math.min(560, MediaQuery.sizeOf(context).height * .56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
