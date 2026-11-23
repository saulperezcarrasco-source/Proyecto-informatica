import 'package:material_ui/material_ui.dart';

import '../map/route_endpoint.dart';
import 'home_controller.dart';

class PlanningEndpoints extends StatelessWidget {
  const PlanningEndpoints({
    super.key,
    required this.controller,
    required this.originText,
    required this.destinationText,
    required this.onSearch,
    required this.onActivate,
    required this.onChooseMap,
  });
  final HomeController controller;
  final TextEditingController originText, destinationText;
  final void Function(Selection, String) onSearch;
  final ValueChanged<Selection> onActivate, onChooseMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget field(Selection target) {
      final destination = target == Selection.destination;
      final text = destination ? destinationText : originText;
      final active = controller.selection == target;
      final name = destination ? 'destino' : 'origen';
      return TextField(
        key: ValueKey(destination ? 'destination-search' : 'origin-search'),
        controller: text,
        onTap: () => onActivate(target),
        onChanged: (value) => onSearch(target, value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'Elegir $name',
          hintText: 'Buscar un lugar',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: RouteEndpoint(destination: destination, size: 28),
          ),
          filled: true,
          fillColor: active ? scheme.primaryContainer : scheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: active ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Borrar $name',
                onPressed: () {
                  text.clear();
                  onSearch(target, '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
              IconButton(
                tooltip: active ? 'Cancelar selección' : 'Elegir $name en mapa',
                onPressed: () => onChooseMap(target),
                icon: Icon(
                  active ? Icons.close_fullscreen_rounded : Icons.map_outlined,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        field(Selection.origin),
        const SizedBox(height: 14),
        field(Selection.destination),
      ],
    );
  }
}
