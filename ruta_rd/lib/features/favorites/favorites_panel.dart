import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import 'favorite_repository.dart';
import 'favorites_controller.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.controller,
    required this.entry,
  });
  final FavoritesController controller;
  final Favorite entry;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final saved = controller.contains(entry);
      return Semantics(
        toggled: saved,
        child: IconButton(
          tooltip: saved ? 'Quitar de favoritos' : 'Guardar en favoritos',
          onPressed: controller.ready && !controller.busy
              ? () => controller.toggle(entry)
              : null,
          icon: Icon(saved ? Icons.star_rounded : Icons.star_border_rounded),
        ),
      );
    },
  );
}

class FavoritesPanel extends StatefulWidget {
  const FavoritesPanel({
    super.key,
    required this.controller,
    required this.region,
    required this.places,
    required this.onOrigin,
    required this.onDestination,
    this.initiallyExpanded = false,
    this.showToggle = true,
  });
  final FavoritesController controller;
  final RegionManifest region;
  final List<Place> places;
  final ValueChanged<Place> onOrigin, onDestination;
  final bool initiallyExpanded, showToggle;
  @override
  State<FavoritesPanel> createState() => _FavoritesPanelState();
}

class _FavoritesPanelState extends State<FavoritesPanel> {
  late bool expanded = widget.initiallyExpanded;
  Place? resolve(Favorite entry) {
    if (entry.regionId != widget.region.id &&
        entry.regionId != 'dominican-search') {
      return null;
    }
    for (final place in widget.places) {
      if (place.id == entry.placeId) return place;
    }
    return null;
  }

  Future<void> reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer favoritos'),
        content: const Text(
          'Se vaciará la lista de favoritos guardada. El mapa y tus ajustes se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.controller.reset();
  }

  void select(Place place, ValueChanged<Place> callback) {
    setState(() => expanded = false);
    callback(place);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showToggle)
            TextButton.icon(
              key: const ValueKey('favorites-panel-toggle'),
              onPressed: () => setState(() => expanded = !expanded),
              icon: const Icon(Icons.star_rounded),
              label: Text(
                '${expanded ? "Ocultar favoritos" : "Favoritos"} (${controller.entries.length})',
              ),
            ),
          if (controller.busy) const LinearProgressIndicator(minHeight: 2),
          if (controller.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(controller.error, semanticsLabel: controller.error),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: controller.busy ? null : controller.load,
                        child: const Text('Reintentar favoritos'),
                      ),
                      if (controller.invalidData)
                        TextButton(
                          onPressed: controller.busy ? null : reset,
                          child: const Text('Restablecer favoritos'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      if (controller.ready && controller.entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Guarda un lugar con la estrella para verlo aquí.',
                          ),
                        ),
                      for (final entry in controller.entries)
                        Builder(
                          builder: (context) {
                            final place = resolve(entry);
                            return ListTile(
                              key: ValueKey(
                                'favorite-${entry.regionId}-${entry.placeId}',
                              ),
                              contentPadding: EdgeInsets.zero,
                              title: Text(place?.name ?? 'Lugar no disponible'),
                              subtitle: place == null
                                  ? const Text(
                                      'Este lugar ya no está disponible. Puedes eliminarlo.',
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              select(place, widget.onOrigin),
                                          child: const Text('Usar como origen'),
                                        ),
                                        TextButton(
                                          onPressed: () => select(
                                            place,
                                            widget.onDestination,
                                          ),
                                          child: const Text(
                                            'Usar como destino',
                                          ),
                                        ),
                                      ],
                                    ),
                              trailing: FavoriteButton(
                                controller: controller,
                                entry: entry,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}
