import 'package:material_ui/material_ui.dart';

import 'dart:async';

import 'core/theme_preferences.dart';
import 'core/brand_logo.dart';

import 'features/home/home_screen.dart';

void main() => runApp(const RutaRdApp());

class RutaRdApp extends StatefulWidget {
  const RutaRdApp({super.key});

  @override
  State<RutaRdApp> createState() => _RutaRdAppState();
}

class _RutaRdAppState extends State<RutaRdApp> {
  final preferences = ThemePreferences();
  @override
  void initState() {
    super.initState();
    unawaited(preferences.load());
  }

  @override
  void dispose() {
    preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ThemePreferencesScope(
    controller: preferences,
    child: ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => MaterialApp(
        title: 'Ruta RD Offline',
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xfff4f7f6),
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xff101c1a),
        ),
        themeMode: preferences.mode,
        themeAnimationDuration:
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
        home: const BrandLaunch(child: HomeScreen()),
      ),
    ),
  );
}
