import 'package:material_ui/material_ui.dart';

/// Attribution stays beside the map, outside its interactive canvas.
class MapCredits extends StatelessWidget {
  const MapCredits({super.key});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Información cartográfica'),
        content: const SingleChildScrollView(
          child: SelectableText(
            'Datos © OpenStreetMap contributors, ODbL 1.0.\n'
            'https://www.openstreetmap.org/copyright\n\n'
            'Cartografía: Protomaps. Datos de Natural Earth: dominio público.\n'
            'Datos y estilos locales; sin descarga de mapas durante el uso.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        '© OpenStreetMap · Protomaps · Natural Earth',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
