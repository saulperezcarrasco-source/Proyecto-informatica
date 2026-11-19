import 'package:material_ui/material_ui.dart';

import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});
  final HomeController? controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController controller;
  late final bool ownsController;

  @override
  void initState() {
    super.initState();
    ownsController = widget.controller == null;
    controller = widget.controller ?? HomeController();
  }

  @override
  void dispose() {
    if (ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => switch (controller.state) {
          RegionState.loading => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando la región...'),
              ],
            ),
          ),
          RegionState.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar la región.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.retry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
          RegionState.ready => const _HomeContent(),
        },
      ),
    ),
  );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.zero,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_walk_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ruta RD Offline',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Buscar un lugar',
                  helperText: 'Búsqueda disponible en una próxima fase',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(minHeight: 360),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Mapa pendiente de integrar',
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Vista de muestra, sin cartografía',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tu recorrido',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const ListTile(
                        leading: CircleAvatar(child: Text('A')),
                        title: Text('Origen'),
                        subtitle: Text('Sin seleccionar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const ListTile(
                        leading: CircleAvatar(child: Text('B')),
                        title: Text('Destino'),
                        subtitle: Text('Sin seleccionar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'La selección de puntos y el cálculo estarán disponibles en próximas fases.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: null,
                            icon: Icon(Icons.my_location),
                            label: Text('Mi ubicación'),
                          ),
                          FilledButton.icon(
                            onPressed: null,
                            icon: Icon(Icons.directions_walk),
                            label: Text('Calcular ruta'),
                          ),
                          TextButton(onPressed: null, child: Text('Limpiar')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                'Los resultados de búsqueda y el resumen de ruta aparecerán aquí cuando estén disponibles.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
