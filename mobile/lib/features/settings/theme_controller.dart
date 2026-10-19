import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';

/// Holds the user's theme choices (light/dark mode and accent colour) and
/// persists them. Never throws.
class ThemeController extends ChangeNotifier {
  ThemeController({
    this.mode = ThemeMode.system,
    this.seed = AppTheme.defaultSeed,
  });

  static const _modeKey = 'theme_mode_v1';
  static const _seedKey = 'theme_seed_v1';

  ThemeMode mode;
  Color seed;

  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_modeKey);
      final modes = ThemeMode.values.where((m) => m.name == name);
      final argb = prefs.getInt(_seedKey);
      return ThemeController(
        mode: modes.isEmpty ? ThemeMode.system : modes.first,
        seed: argb == null ? AppTheme.defaultSeed : Color(argb | 0xFF000000),
      );
    } catch (_) {
      return ThemeController();
    }
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    notifyListeners();
    await _save((p) => p.setString(_modeKey, value.name));
  }

  Future<void> setSeed(Color value) async {
    seed = value;
    notifyListeners();
    await _save((p) => p.setInt(_seedKey, value.toARGB32()));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }
}
