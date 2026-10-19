import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/app.dart';
import 'package:moneykit/core/theme.dart';
import 'package:moneykit/features/calculators/calculators_screen.dart';
import 'package:moneykit/features/settings/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 1600),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const CalculatorsScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _segment(String t) => find.descendant(
  of: find.byType(SegmentedButton<int>),
  matching: find.text(t),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('switcher shows each calculator with its original title', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Interest Calculator'), findsOneWidget);
    for (final (seg, title) in [
      ('Mortgage', 'Mortgage Calculator'),
      ('CPF', 'CPF Interest Calculator'),
      ('Interest', 'Interest Calculator'),
    ]) {
      await tester.tap(_segment(seg));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('each calculator keeps its inputs while switching', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Principal'),
      '10000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Annual interest rate'),
      '5',
    );
    await tester.pumpAndSettle();
    expect(find.text('\$16,470.09'), findsWidgets);

    await tester.tap(_segment('Mortgage'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Loan amount'),
      '500000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Annual interest rate'),
      '4',
    );
    await tester.pumpAndSettle();
    expect(find.text('\$2,639.18'), findsWidgets);

    await tester.tap(_segment('Interest'));
    await tester.pumpAndSettle();
    expect(find.text('\$16,470.09'), findsWidgets);
    await tester.tap(_segment('Mortgage'));
    await tester.pumpAndSettle();
    expect(find.text('\$2,639.18'), findsWidgets);
  });

  for (final size in [const Size(320, 568), const Size(360, 640)]) {
    testWidgets('no overflow at ${size.width.toInt()}dp with 1.5x text', (
      tester,
    ) async {
      await _pump(tester, size: size, scale: 1.5);
      for (final seg in ['Mortgage', 'CPF', 'Interest']) {
        await tester.tap(_segment(seg));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bottom bar has four labelled tabs and fits 320dp at 1.5x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.5),
        ),
        child: MoneyKitApp(themeController: ThemeController()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dests = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .toList();
    expect(dests.map((d) => d.label), ['MAB', 'Tools', 'Split', 'Settings']);
    for (final d in dests) {
      final rect = tester.getRect(
        find.widgetWithText(NavigationDestination, d.label),
      );
      expect(rect.width, greaterThanOrEqualTo(48));
    }
  });
}
