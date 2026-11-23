import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

const routeInstructions =
    'Para trazar una ruta personalizada:\nPrimero, toca donde se iniciará la ruta para elegir el origen.\nPor último, toca hacia donde vas para elegir el destino.';

/// Reserve the measured instruction height even while replacing a point.
/// Large text stays readable without shifting the map when A/B changes.
class RouteInstructions extends StatelessWidget {
  const RouteInstructions({super.key, this.selection});
  final Widget? selection;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodyMedium!;
      final text = TextPainter(
        text: TextSpan(text: routeInstructions, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final height = math.max(60.0, text.height + 16);
      text.dispose();
      return SizedBox(
        height: height,
        child:
            selection ??
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(routeInstructions),
            ),
      );
    },
  );
}
