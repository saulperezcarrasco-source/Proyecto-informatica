import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../favorites/favorite_repository.dart';
import '../favorites/favorites_controller.dart';
import '../favorites/favorites_panel.dart';
import 'home_controller.dart';

/// Results scroll inside the space assigned to the map, never the whole page.
class HomeSearchResults extends StatelessWidget {
  const HomeSearchResults({
    super.key,
    required this.controller,
    required this.favorites,
    required this.target,
    required this.onSelect,
  });
  final HomeController controller;
  final FavoritesController favorites;
  final Selection target;
  final ValueChanged<Place> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (c.searchBusy) const LinearProgressIndicator(),
          if (c.searchNotice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                c.searchNotice,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Expanded(
            child: c.results.isEmpty
                ? Center(
                    child: Text(
                      c.searchBusy
                          ? 'Buscando lugares…'
                          : 'No se encontraron lugares.',
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('search-results'),
                    padding: EdgeInsets.zero,
                    itemCount: c.results.length,
                    itemBuilder: (context, index) {
                      final place = c.results[index];
                      return ListTile(
                        title: Text(place.name),
                        onTap: () => onSelect(place),
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
                        subtitle: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => onSelect(place),
                            child: Text(
                              target == Selection.origin
                                  ? 'Usar como origen'
                                  : 'Usar como destino',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
