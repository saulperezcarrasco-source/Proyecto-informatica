import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferences extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  SharedPreferences? _storage;
  bool _disposed = false;
  int _revision = 0;

  Future<void> load() async {
    final revision = _revision;
    try {
      final storage = await SharedPreferences.getInstance();
      if (_disposed) return;
      _storage = storage;
      if (revision != _revision) {
        await _persist();
        return;
      }
      final dark = storage.getBool('darkMode');
      mode = dark == null
          ? ThemeMode.system
          : dark
          ? ThemeMode.dark
          : ThemeMode.light;
      notifyListeners();
    } catch (_) {
      /* Use the system theme if local preferences are unavailable. */
    }
  }

  Future<void> toggle(Brightness current) async {
    _revision++;
    mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _storage?.setBool('darkMode', mode == ThemeMode.dark);
    } catch (_) {
      /* The current session keeps its theme. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ThemePreferencesScope extends InheritedNotifier<ThemePreferences> {
  const ThemePreferencesScope({
    super.key,
    required ThemePreferences controller,
    required super.child,
  }) : super(notifier: controller);
  static ThemePreferences? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ThemePreferencesScope>()
      ?.notifier;
}
