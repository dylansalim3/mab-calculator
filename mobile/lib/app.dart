import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/calculators/calculators_screen.dart';
import 'features/mab/mab_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/split/split_screen.dart';
import 'features/settings/theme_controller.dart';

class MoneyKitApp extends StatelessWidget {
  const MoneyKitApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'MoneyKit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(seed: themeController.seed),
        darkTheme: AppTheme.dark(seed: themeController.seed),
        themeMode: themeController.mode,
        home: Shell(themeController: themeController),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const MabScreen(),
          const CalculatorsScreen(),
          const SplitScreen(),
          SettingsScreen(theme: widget.themeController),
        ],
      ),
      bottomNavigationBar: MediaQuery(
        // Bar labels are one short word each; keep them on one line at big fonts.
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.3),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'MAB',
            ),
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'Tools',
              tooltip: 'Interest, Mortgage and CPF calculators',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Split',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
