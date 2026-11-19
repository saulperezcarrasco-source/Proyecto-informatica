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
        builder: (context, _) => AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (controller.state) {
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
    ),
  );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xffe8f1ee),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight * .56,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_walk_rounded,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ruta RD Offline',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Material(
                              color: Colors.white,
                              elevation: 2,
                              shadowColor: const Color(0x22000000),
                              borderRadius: BorderRadius.circular(28),
                              child: const TextField(
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Buscar un lugar',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Búsqueda disponible próximamente',
                              style: TextStyle(color: Color(0xff526963)),
                            ),
                            const SizedBox(height: 46),
                            const Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 48,
                                    color: Color(0xff7c9b92),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Mapa pendiente de integrar',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Vista de muestra, sin cartografía',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xff526963)),
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
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tu recorrido',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Elige tu punto de partida y destino',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          const ListTile(
                            leading: CircleAvatar(child: Text('A')),
                            title: Text('Origen'),
                            subtitle: Text('Sin seleccionar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(height: 1),
                          const ListTile(
                            leading: CircleAvatar(child: Text('B')),
                            title: Text('Destino'),
                            subtitle: Text('Sin seleccionar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Mi ubicación'),
                              ),
                              FilledButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.directions_walk),
                                label: const Text('Calcular ruta'),
                              ),
                              const TextButton(
                                onPressed: null,
                                child: Text('Limpiar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selección y rutas disponibles próximamente.',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
