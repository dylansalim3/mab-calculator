import 'package:flutter/material.dart';

import 'app.dart';
import 'features/settings/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.load();
  runApp(MoneyKitApp(themeController: themeController));
}
