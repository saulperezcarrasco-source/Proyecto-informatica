import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/models/models.dart';
import '../../core/distance_format.dart';
import '../../core/map_credits.dart';

import '../home/home_controller.dart';
import '../location/location_service.dart';
import '../map/local_map.dart';
import 'navigation_controller.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.home, this.navigation});
  final HomeController home;
  final NavigationController? navigation;
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  late final NavigationController nav;
  bool _resumeOnForeground = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    nav =
        widget.navigation ??
        NavigationController(
          route: widget.home.route!,
          destination: widget.home.destination!.coordinate,
          origin: widget.home.origin?.coordinate,
          location: widget.home.location,
        );
    nav.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _resumeOnForeground = _resumeOnForeground || nav.active;
      if (nav.active) nav.stop();
    } else if (state == AppLifecycleState.resumed && _resumeOnForeground) {
      _resumeOnForeground = false;
      nav.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.navigation == null) nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const MapCredits(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: LocalMap(
                      controller: widget.home,
                      navigation: nav,
                      height: constraints.maxHeight,
                    ),
                  ),
                  Positioned(
                    top: 76,
                    left: 12,
                    right: 12,
                    child: ListenableBuilder(
                      listenable: nav,
                      builder: (context, _) => Card(
                        color: const Color(0xff064e46),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Icon(
                                nav.arrived
                                    ? Icons.flag_rounded
                                    : nav.instruction.contains('derecha')
                                    ? Icons.turn_right_rounded
                                    : nav.instruction.contains('izquierda')
                                    ? Icons.turn_left_rounded
                                    : Icons.straight_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      nav.instruction,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      nav.arrived
                                          ? 'Destino alcanzado'
                                          : 'En ${formatDistance(nav.instructionMeters)} · ${nav.route.mode.label.toLowerCase()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 45,
                    child: ListenableBuilder(
                      listenable: nav,
                      builder: (context, _) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${formatDistance(nav.remainingMeters)} restantes · ${nav.remainingMinutes} min',
                                key: const ValueKey('navigation-remaining'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                nav.status,
                                key: const ValueKey('navigation-status'),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (nav.failure ==
                                          LocationFailure
                                              .precisePermissionRequired ||
                                      nav.failure ==
                                          LocationFailure.permissionDenied ||
                                      nav.failure ==
                                          LocationFailure
                                              .permissionDeniedForever)
                                    TextButton(
                                      onPressed: () {
                                        _resumeOnForeground = true;
                                        Geolocator.openAppSettings();
                                      },
                                      child: const Text(
                                        'Permisos de ubicación',
                                      ),
                                    ),
                                  if (nav.failure ==
                                      LocationFailure.serviceDisabled)
                                    TextButton(
                                      onPressed: () {
                                        _resumeOnForeground = true;
                                        Geolocator.openLocationSettings();
                                      },
                                      child: const Text('Activar ubicación'),
                                    ),
                                  if (nav.offRoute && nav.position != null)
                                    FilledButton.icon(
                                      onPressed: () {
                                        widget.home.selectAndRoute(
                                          Place(
                                            id: 'gps',
                                            name: 'Mi ubicación',
                                            category: 'gps',
                                            coordinate: nav.position!,
                                          ),
                                          Selection.origin,
                                        );
                                        Navigator.of(context).pop();
                                      },
                                      icon: const Icon(Icons.alt_route),
                                      label: const Text(
                                        'Recalcular desde mi posición',
                                      ),
                                    ),
                                  FilledButton.icon(
                                    onPressed: nav.active
                                        ? () => nav.stop()
                                        : nav.start,
                                    icon: Icon(
                                      nav.active
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                                    label: Text(
                                      nav.active ? 'Pausar' : 'Continuar',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => nav.setFollow(true),
                                    icon: const Icon(Icons.my_location),
                                    label: const Text('Seguir mi posición'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Salir'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton.filled(
                      tooltip: 'Volver al mapa',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
