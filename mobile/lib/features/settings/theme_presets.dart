import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ThemePreset {
  const ThemePreset(this.name, this.color);

  final String name;
  final Color color;
}

/// Accent colours offered in Settings. Material 3 derives a full, contrast-safe
/// scheme from each one, so "light" hues still give readable text.
const themePresets = [
  ThemePreset('Default', AppTheme.defaultSeed),
  ThemePreset('Light blue', Color(0xFF4FC3F7)),
  ThemePreset('Light green', Color(0xFF81C784)),
  ThemePreset('Light red', Color(0xFFE57373)),
  ThemePreset('Light orange', Color(0xFFFFB74D)),
  ThemePreset('Light purple', Color(0xFFBA68C8)),
  ThemePreset('Light yellow', Color(0xFFFFF176)),
];
