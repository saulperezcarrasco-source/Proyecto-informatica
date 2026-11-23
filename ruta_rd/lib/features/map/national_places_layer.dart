import 'package:flutter/semantics.dart' show SemanticsProperties;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../search/place_catalog.dart';

class PlaceLabelHits {
  final List<(Rect, Place)> labels = [];
  Place? at(Offset offset) {
    for (final label in labels.reversed) {
      if (label.$1.inflate(5).contains(offset)) return label.$2;
    }
    return null;
  }
}

/// A bounded canvas layer replaces thousands of individual place widgets.
/// Label layout considers only nearby indexed cells and avoids text collisions.
class NationalPlacesLayer extends StatefulWidget {
  const NationalPlacesLayer({
    super.key,
    required this.catalog,
    required this.hits,
    required this.onPlace,
    this.selected = const [],
    this.interactive = true,
  });
  final PlaceCatalog? catalog;
  final PlaceLabelHits hits;
  final ValueChanged<Place> onPlace;
  final List<Place> selected;
  final bool interactive;
  @override
  State<NationalPlacesLayer> createState() => _NationalPlacesLayerState();
}

class _NationalPlacesLayerState extends State<NationalPlacesLayer> {
  final texts = <String, TextPainter>{};
  @override
  void dispose() {
    for (final text in texts.values) {
      text.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context), bounds = camera.visibleBounds;
    final visible =
        widget.catalog?.visible(
          RegionBounds(
            south: bounds.south,
            west: bounds.west,
            north: bounds.north,
            east: bounds.east,
          ),
          camera.zoom,
        ) ??
        const <Place>[];
    final selected = widget.selected
        .where((p) => p.category != 'manual' && p.category != 'gps')
        .toList();
    final ids = selected.map((p) => p.id).toSet();
    final places = [...selected, ...visible.where((p) => !ids.contains(p.id))];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: widget.interactive
            ? (event) {
                final p = widget.hits.at(event.localPosition);
                if (p != null) widget.onPlace(p);
              }
            : null,
        child: CustomPaint(
          painter: _PlacePainter(
            camera: camera,
            places: camera.zoom >= 14 ? places : const [],
            texts: texts,
            hits: widget.hits,
            dark: dark,
            selected: ids,
            onPlace: widget.interactive ? widget.onPlace : null,
          ),
        ),
      ),
    );
  }
}

class _PlacePainter extends CustomPainter {
  _PlacePainter({
    required this.camera,
    required this.places,
    required this.texts,
    required this.hits,
    required this.dark,
    required this.selected,
    required this.onPlace,
  });
  final MapCamera camera;
  final List<Place> places;
  final Map<String, TextPainter> texts;
  final PlaceLabelHits hits;
  final bool dark;
  final Set<String> selected;
  final ValueChanged<Place>? onPlace;
  @override
  void paint(Canvas canvas, Size size) {
    hits.labels.clear();
    final occupied = <Rect>[];
    final screen = Offset.zero & size;
    canvas.save();
    canvas.clipRect(screen);
    for (final p in places) {
      final point = camera.latLngToScreenOffset(
        LatLng(p.coordinate.lat, p.coordinate.lon),
      );
      if (point.dx < 0 ||
          point.dy < 0 ||
          point.dx > size.width ||
          point.dy > size.height - 32) {
        continue;
      }
      final active = selected.contains(p.id);
      final color = dark
          ? const Color(0xffe1cef9)
          : p.category == 'turismo'
          ? const Color(0xff126b5d)
          : const Color(0xff684299);
      final key = '${p.name}:$dark:$active:${p.category == 'turismo'}';
      var text = texts.remove(key);
      text ??= TextPainter(
        text: TextSpan(
          text: p.name,
          style: TextStyle(
            fontSize: active ? 12 : 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 165);
      texts[key] = text;
      while (texts.length > 400) {
        texts.remove(texts.keys.first)?.dispose();
      }
      final origin = Offset(
        active
            ? (point.dx + 23).clamp(4.0, size.width - text.width - 4)
            : point.dx + 8,
        point.dy - text.height / 2,
      );
      final rect = Rect.fromLTWH(
        origin.dx - 3,
        origin.dy - 2,
        text.width + 6,
        text.height + 4,
      );
      if (!screen.contains(rect.topLeft) ||
          !screen.contains(rect.bottomRight)) {
        continue;
      }
      if (!active && occupied.any((r) => r.overlaps(rect.inflate(3)))) continue;
      occupied.add(rect);
      hits.labels.add((
        rect.expandToInclude(Rect.fromCircle(center: point, radius: 7)),
        p,
      ));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = dark ? const Color(0xef172723) : const Color(0xf5ffffff),
      );
      canvas.drawCircle(
        point,
        4,
        Paint()..color = dark ? const Color(0xff172723) : Colors.white,
      );
      canvas.drawCircle(point, 2.6, Paint()..color = color);
      text.paint(canvas, origin);
      if (hits.labels.length >= 45) break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlacePainter oldDelegate) => true;
  @override
  bool shouldRebuildSemantics(covariant _PlacePainter oldDelegate) => true;
  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final hit in hits.labels)
          CustomPainterSemantics(
            key: ValueKey(hit.$2.id),
            rect: hit.$1,
            properties: SemanticsProperties(
              label: '${hit.$2.name}, ${hit.$2.category}',
              textDirection: TextDirection.ltr,
              onTap: onPlace == null ? null : () => onPlace!(hit.$2),
            ),
          ),
      ];
}
