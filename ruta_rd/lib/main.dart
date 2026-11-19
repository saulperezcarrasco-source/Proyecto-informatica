import 'package:material_ui/material_ui.dart';

void main() => runApp(const RutaRdApp());

class RutaRdApp extends StatelessWidget {
  const RutaRdApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ruta RD Offline',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const Scaffold(
      body: SafeArea(child: Center(child: Text('Ruta RD Offline'))),
    ),
  );
}
