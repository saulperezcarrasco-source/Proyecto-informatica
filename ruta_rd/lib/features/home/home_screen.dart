import 'dart:async';

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
import 'home_search_results.dart';
import '../map/local_map.dart';
import '../location/location_service.dart';

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

  Widget header(BuildContext context, bool compact) {
    final c = controller;
    return Row(
      children: [
        Image.asset(
          'assets/brand/ruta_symbol.png',
          width: compact ? 24 : 34,
          height: compact ? 24 : 34,
          cacheWidth: 102,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 8),
        if (!compact)
          Expanded(
            child: Text(
              'Ruta RD',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          )
        else
          const Spacer(),
        IconButton(
          tooltip: c.locating ? 'Cancelar GPS' : 'Mi ubicación',
          onPressed: c.locating ? c.cancelLocation : c.locate,
          icon: c.locating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded),
        ),
        IconButton(
          key: const ValueKey('favorites-panel-toggle'),
          tooltip: 'Favoritos',
          onPressed: openFavorites,
          icon: const Icon(Icons.star_border_rounded),
        ),
        if (compact)
          PopupMenuButton<TravelMode>(
            tooltip: 'Transporte',
            icon: Icon(modeIcon(c.travelMode)),
            onSelected: c.setTravelMode,
            itemBuilder: (_) => [
              for (final mode in TravelMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(modeIcon(mode)),
                      const SizedBox(width: 12),
                      Text(mode.label),
                    ],
                  ),
                ),
            ],
          ),
        if (ThemePreferencesScope.of(context) != null)
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
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
    );
  }

  void clearPlanning() {
    FocusScope.of(context).unfocus();
    editingTarget = null;
    originText.clear();
    destinationText.clear();
    controller.clear();
  }

  Widget actions(BuildContext context, bool compact, {bool more = false}) {
    final c = controller;
    final label = c.calculating
        ? 'Calculando…'
        : c.route != null
        ? 'Iniciar navegación'
        : 'Calcular ruta';
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: label,
            child: FilledButton.icon(
              key: const ValueKey('route-action'),
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
                compact
                    ? (c.calculating
                          ? '…'
                          : c.route != null
                          ? 'Ir'
                          : 'Ruta')
                    : label,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (compact)
          IconButton(
            key: const ValueKey('clear-planning'),
            tooltip: 'Limpiar',
            onPressed: clearPlanning,
            icon: const Icon(Icons.restart_alt_rounded),
          )
        else
          TextButton(
            key: const ValueKey('clear-planning'),
            onPressed: clearPlanning,
            child: const Text('Limpiar'),
          ),
        if (c.route != null)
          IconButton(
            tooltip: 'Detalles de ruta',
            onPressed: routeDetails,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        if (more)
          PopupMenuButton<Object>(
            tooltip: 'Más opciones',
            onSelected: (choice) {
              if (choice is TravelMode) {
                c.setTravelMode(choice);
              } else if (choice == 'gps') {
                c.locate();
              } else if (choice == 'favorites') {
                openFavorites();
              } else if (choice == 'theme') {
                ThemePreferencesScope.of(context)
                    ?.toggle(Theme.of(context).brightness);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'gps', child: Text('Mi ubicación')),
              const PopupMenuItem(value: 'favorites', child: Text('Favoritos')),
              if (ThemePreferencesScope.of(context) != null)
                const PopupMenuItem(
                  value: 'theme',
                  child: Text('Cambiar tema'),
                ),
              for (final mode in TravelMode.values)
                PopupMenuItem(value: mode, child: Text(mode.label)),
            ],
          ),
      ],
    );
  }

  Widget status(BuildContext context, bool compact) {
    final c = controller;
    final message = c.locationFailure != null
        ? c.locationMessage
        : c.message.isNotEmpty && c.selection == null
        ? c.message
        : c.accuracy != null && c.origin?.category == 'gps'
        ? 'Precisión de ubicación: ±${c.accuracy!.round()} m'
        : '';
    if (message.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Estado del recorrido'),
          content: Text(message),
          actions: [
            if (c.locationFailure == LocationFailure.serviceDisabled)
              TextButton(
                onPressed: Geolocator.openLocationSettings,
                child: const Text('Activar ubicación'),
              ),
            if (c.locationFailure == LocationFailure.permissionDeniedForever)
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: const Text('Abrir permisos de la app'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
      child: Text(
        message,
        maxLines: compact ? 1 : 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          if (c.state == RegionState.loading) return const BrandLoading();
          if (c.state == RegionState.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.message, textAlign: TextAlign.center),
                  FilledButton(
                    onPressed: c.retry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, bounds) {
              final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
              final searching = c.query.trim().isNotEmpty;
              final compact =
                  bounds.maxHeight < 600 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final short = bounds.maxHeight < 360;
              final editing = keyboard || searching;
              return Padding(
                padding: EdgeInsets.fromLTRB(12, compact ? 4 : 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!short) header(context, compact),
                    const SizedBox(height: 6),
                    PlanningEndpoints(
                      controller: c,
                      originText: originText,
                      destinationText: destinationText,
                      onSearch: searchEndpoint,
                      onActivate: activateSearch,
                      onChooseMap: chooseMap,
                      horizontal: bounds.maxWidth >= 600 && compact,
                    ),
                    const SizedBox(height: 8),
                    if (!compact && !editing)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
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
                    if (!editing) ...[
                      actions(context, compact, more: short),
                      if (!compact)
                        SizedBox(
                          height:
                              MediaQuery.textScalerOf(context).scale(14) * 1.6,
                          child: c.route == null
                              ? null
                              : Text(
                                  key: const ValueKey('route-summary'),
                                  '${formatDistance(c.route!.distanceMeters)} · ${c.route!.estimatedMinutes.ceil()} min aprox. · ${c.route!.mode.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      status(context, compact),
                    ],
                    const MapCredits(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, space) => Stack(
                          fit: StackFit.expand,
                          children: [
                            LocalMap(
                              key: const ValueKey('local-map'),
                              controller: c,
                              height: space.maxHeight,
                            ),
                            if (searching)
                              Positioned.fill(
                                child: HomeSearchResults(
                                  controller: c,
                                  favorites: favorites,
                                  target: searchTarget,
                                  onSelect: (place) =>
                                      select(place, searchTarget),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
