// Fixture for manually checking the Android keyboard. It does not search.
import 'package:material_ui/material_ui.dart';
import 'package:ruta_rd/features/home/home_screen.dart';

void main() => runApp(const MaterialApp(home: HomeScreen(searchPreview: true)));
