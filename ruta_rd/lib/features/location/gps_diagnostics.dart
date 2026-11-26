import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class GpsDiagnostics {
  GpsDiagnostics(this.data);
  final Map<String, dynamic> data;
  static const channel = MethodChannel('ruta_rd/gps_diagnostics');
  static Future<GpsDiagnostics> read() async => GpsDiagnostics(
    Map<String, dynamic>.from(await channel.invokeMapMethod('snapshot') ?? {}),
  );
  String get explanation {
    if (data.isEmpty) return 'No se pudo consultar el receptor GPS.';
    if (data['precisePermission'] != true) {
      return 'Falta el permiso de ubicación precisa.';
    }
    if (data['gpsEnabled'] != true) return 'El GPS del teléfono está apagado.';
    if (data['tracking'] != true) return 'El seguimiento GPS está pausado.';
    final age = data['fixAgeMillis'] as num?;
    if (age != null && age <= 15000) {
      final accuracy = data['accuracyMeters'] as num?;
      return accuracy != null && accuracy <= 35
          ? 'Android está entregando posiciones GPS recientes.'
          : 'Android recibe posición, pero su precisión todavía es insuficiente para avanzar la ruta.';
    }
    if ((data['visibleSatellites'] as num? ?? 0) > 0) {
      return 'El receptor detecta satélites, pero todavía no entrega una posición reciente.';
    }
    return 'Aún no hay posición GPS reciente. La ausencia de datos de satélites no demuestra que el receptor esté averiado.';
  }

  String get report => [
    'Ruta RD Offline · diagnóstico GPS',
    'Versión: ${data['version'] ?? 'sin dato'}',
    'Dispositivo: ${data['device'] ?? 'sin dato'} · Android ${data['android'] ?? 'sin dato'}',
    explanation,
    'Permiso preciso: ${data['precisePermission']}',
    'GPS encendido: ${data['gpsEnabled']}; seguimiento: ${data['tracking']}',
    'Satélites visibles: ${data['visibleSatellites'] ?? 'sin dato'}; usados: ${data['usedSatellites'] ?? 'sin dato'}',
    'Antigüedad del estado satelital (ms): ${data['satelliteStatusAgeMillis'] ?? 'sin dato'}',
    'Posiciones recibidas: ${data['fixesReceived'] ?? 0}',
    'Antigüedad de posición (ms): ${data['fixAgeMillis'] ?? 'sin dato'}',
    'Precisión (m): ${data['accuracyMeters'] ?? 'sin dato'}',
    'Velocidad (m/s): ${data['speedMetersPerSecond'] ?? 'sin dato'}; precisión: ${data['speedAccuracy'] ?? 'sin dato'}',
  ].join('\n');
}

class GpsDiagnosticsPanel extends StatefulWidget {
  const GpsDiagnosticsPanel({super.key, required this.navigationStatus});
  final String Function() navigationStatus;
  @override
  State<GpsDiagnosticsPanel> createState() => _GpsDiagnosticsPanelState();
}

class _GpsDiagnosticsPanelState extends State<GpsDiagnosticsPanel> {
  GpsDiagnostics? value;
  bool failed = false, busy = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    try {
      final result = await GpsDiagnostics.read();
      if (mounted) {
        setState(() {
          value = result;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      busy = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Estado del GPS',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (failed)
              const Text(
                'No se pudo leer el diagnóstico GPS. Puedes reintentar.',
              ),
            if (value == null && !failed) const LinearProgressIndicator(),
            if (value != null) Text(value!.report),
            const SizedBox(height: 12),
            Text('App: ${widget.navigationStatus()}'),
            const SizedBox(height: 12),
            const Text(
              'Se actualiza cada 2 s. Este diagnóstico funciona sin internet y no incluye tus coordenadas.',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: refresh, child: const Text('Actualizar')),
                if (value != null)
                  FilledButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              '${value!.report}\nApp: ${widget.navigationStatus()}',
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Diagnóstico copiado')),
                        );
                      }
                    },
                    child: const Text('Copiar diagnóstico'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
