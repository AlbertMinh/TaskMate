// lib/providers/app_settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModePref { system, light, dark }

class AppSettings extends ChangeNotifier {
  ThemeModePref themeMode = ThemeModePref.system;
  MaterialColor accent = Colors.green;
  bool showCompleted = true;

  ThemeData get currentThemeData {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: accent),
      primaryColor: accent,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF0B0B0C),
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey[400],
      ),
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final tm = prefs.getString('pref_theme_mode') ?? 'system';
    themeMode = ThemeModePref.values.firstWhere((e) => e.toString().split('.').last == tm, orElse: () => ThemeModePref.system);
    final accentVal = prefs.getString('pref_accent_color');
    if (accentVal != null) {
      try {
        final v = int.parse(accentVal);
        accent = MaterialColor(v, <int, Color>{500: Color(v)});
      } catch (_) {}
    }
    showCompleted = prefs.getBool('pref_show_completed') ?? true;
    notifyListeners();
  }

  Future<void> setAccent(MaterialColor c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_accent_color', c.value.toString());
    accent = c;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeModePref t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_theme_mode', t.toString().split('.').last);
    themeMode = t;
    notifyListeners();
  }
}
