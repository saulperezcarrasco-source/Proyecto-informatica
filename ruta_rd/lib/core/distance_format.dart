/// Keep metre precision below 1 km; show one decimal km above that threshold.
String formatDistance(double meters) {
  if (!meters.isFinite || meters < 0) return '—';
  if (meters < 1000) return '${meters.floor()} m';
  final km = (meters / 1000).toStringAsFixed(1);
  return '${km.endsWith('.0') ? km.substring(0, km.length - 2) : km} km';
}
