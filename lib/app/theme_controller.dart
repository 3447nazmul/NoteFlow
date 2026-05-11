import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Theme Controller
///
/// Manages the app's theme mode (System / Light / Dark) and
/// persists the user's choice to SharedPreferences.
///
/// Exposed as a ChangeNotifier in the Provider tree so
/// MaterialApp rebuilds when the theme changes.
/// ──────────────────────────────────────────────────────────────

class ThemeController extends ChangeNotifier {
  static const String _key = 'noteflow_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Load the persisted theme mode on app start.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);

    switch (stored) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Set and persist the theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_key, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_key, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_key, 'system');
        break;
    }
  }

  /// Whether dark mode is currently active (checking system if needed).
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
