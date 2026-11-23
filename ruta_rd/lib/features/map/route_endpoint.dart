import 'package:material_ui/material_ui.dart';

/// Shape, symbol, colour and semantics distinguish endpoints without relying
/// on letters or colour alone. The same component is used in the summary.
class RouteEndpoint extends StatelessWidget {
  const RouteEndpoint({super.key, required this.destination, this.size = 38});
  final bool destination;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: destination ? 'Punto B: destino' : 'Punto A: origen',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: destination ? const Color(0xff176ba0) : const Color(0xff008d80),
        shape: destination ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: destination ? BorderRadius.circular(12) : null,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(
        destination ? Icons.flag_rounded : Icons.trip_origin_rounded,
        color: Colors.white,
        size: size * .6,
      ),
    ),
  );
}
