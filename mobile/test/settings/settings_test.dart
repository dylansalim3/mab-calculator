import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/app.dart';
import 'package:moneykit/core/theme.dart';
import 'package:moneykit/features/settings/app_info.dart';
import 'package:moneykit/features/settings/color_picker_dialog.dart';
import 'package:moneykit/features/settings/theme_presets.dart';
import 'package:moneykit/features/settings/settings_screen.dart';
import 'package:moneykit/features/settings/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppInfo> _info() async => const AppInfo(versionName: '1.2.3');

Widget _host(ThemeController c, {AppSharer? sharer}) => ListenableBuilder(
  listenable: c,
  builder: (_, _) => MaterialApp(
    theme: AppTheme.light(seed: c.seed),
    darkTheme: AppTheme.dark(seed: c.seed),
    themeMode: c.mode,
    home: SettingsScreen(
      theme: c,
      infoLoader: _info,
      sharer: sharer ?? () async {},
    ),
  ),
);

Future<void> _openColors(WidgetTester tester) async {
  await tester.tap(find.text('Color theme'));
  await tester.pumpAndSettle();
}

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows theme options, version and disclaimer', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(ThemeController()));
    await tester.pumpAndSettle();
    for (final t in [
      'Settings',
      'Theme',
      'System',
      'Color theme',
      'Default',
      'Share app',
      'About',
      'Version',
      '1.2.3',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.text('Estimates only — not financial advice.'), findsOneWidget);
    // Choices live in dialogs, not inline.
    expect(find.text('Dark'), findsNothing);
    expect(find.text('Light blue'), findsNothing);
  });

  testWidgets('Theme tile opens a dialog listing System, Light, Dark', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ThemeController()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsOneWidget);
    for (final t in ['System', 'Light', 'Dark']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    await tester.tapAt(const Offset(5, 5)); // dismiss
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
  });

  testWidgets('choosing Dark switches the theme and persists it', (
    tester,
  ) async {
    final c = ThemeController();
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
    expect(c.mode, ThemeMode.dark);
    expect(find.text('Dark'), findsOneWidget); // tile subtitle
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    expect((await ThemeController.load()).mode, ThemeMode.dark);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect((await ThemeController.load()).mode, ThemeMode.light);
  });

  test('load falls back to system for missing or junk values', () async {
    expect((await ThemeController.load()).mode, ThemeMode.system);
    SharedPreferences.setMockInitialValues({'theme_mode_v1': 'purple'});
    expect((await ThemeController.load()).mode, ThemeMode.system);
  });

  testWidgets('Share app calls the sharer; failure shows a snackbar', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(ThemeController(), sharer: () async => calls++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share app'));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.pumpWidget(
      _host(ThemeController(), sharer: () async => throw Exception('x')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share app'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the share sheet'), findsOneWidget);
  });

  testWidgets('Settings is the last tab', (tester) async {
    await tester.pumpWidget(MoneyKitApp(themeController: ThemeController()));
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['MAB', 'Tools', 'Split', 'Settings']);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Share app'), findsOneWidget);
  });

  testWidgets('no overflow at 360x640 with 1.5x text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.5),
        ),
        child: _host(ThemeController()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('color theme', () {
    testWidgets('offers the six light colors, default and custom', (
      tester,
    ) async {
      await tester.pumpWidget(_host(ThemeController()));
      await tester.pumpAndSettle();
      await _openColors(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      for (final n in [
        'Default',
        'Light blue',
        'Light green',
        'Light red',
        'Light orange',
        'Light purple',
        'Light yellow',
        'Custom',
      ]) {
        expect(_inDialog(n), findsOneWidget, reason: n);
      }
    });

    for (final p in themePresets) {
      testWidgets('choosing ${p.name} restyles the app and persists', (
        tester,
      ) async {
        final c = ThemeController();
        await tester.pumpWidget(_host(c));
        await tester.pumpAndSettle();
        await _openColors(tester);
        await tester.tap(_inDialog(p.name));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(p.name), findsOneWidget); // tile subtitle
        expect(c.seed, p.color);
        final primary = Theme.of(
          tester.element(find.byType(SettingsScreen)),
        ).colorScheme.primary;
        expect(primary, ColorScheme.fromSeed(seedColor: p.color).primary);
        expect((await ThemeController.load()).seed, p.color);
      });
    }

    testWidgets('Custom opens the picker; Select applies the color', (
      tester,
    ) async {
      final c = ThemeController();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();
      await _openColors(tester);
      await tester.tap(_inDialog('Custom'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a color'), findsOneWidget);
      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a color'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Custom (#'), findsOneWidget);
      expect(c.seed, isNot(AppTheme.defaultSeed));
      expect((await ThemeController.load()).seed, c.seed);
    });

    testWidgets('picker Cancel keeps the current color', (tester) async {
      final c = ThemeController();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();
      await _openColors(tester);
      await tester.tap(_inDialog('Custom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(c.seed, AppTheme.defaultSeed);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    test('colorHex formats RRGGBB', () {
      expect(colorHex(const Color(0xFF4FC3F7)), '#4FC3F7');
      expect(colorHex(const Color(0xFF000A0F)), '#000A0F');
    });

    test('load restores a saved color and ignores none', () async {
      SharedPreferences.setMockInitialValues({'theme_seed_v1': 0xFFE57373});
      expect((await ThemeController.load()).seed, const Color(0xFFE57373));
      SharedPreferences.setMockInitialValues({});
      expect((await ThemeController.load()).seed, AppTheme.defaultSeed);
    });

    testWidgets('swatch grid has no overflow at 360x640, 1.5x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: _host(ThemeController()),
        ),
      );
      await tester.pumpAndSettle();
      await _openColors(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
