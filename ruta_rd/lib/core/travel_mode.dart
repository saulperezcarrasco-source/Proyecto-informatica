enum TravelMode {
  walking('A pie', 'walking', 4.5),
  bicycle('Bici', 'bicycle', 15),
  car('Coche', 'motorcar', 40),
  motorcycle('Moto', 'motorcycle', 35);

  const TravelMode(this.label, this.assetName, this.kilometersPerHour);
  final String label, assetName;
  final double kilometersPerHour;
  double get metersPerMinute => kilometersPerHour * 1000 / 60;
  double minutes(double meters) => meters / metersPerMinute;
}
