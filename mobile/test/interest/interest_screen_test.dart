import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/core/theme.dart';
import 'package:moneykit/core/widgets/widgets.dart';
import 'package:moneykit/features/interest/interest_screen.dart';

Future<void> pumpScreen(
  WidgetTester tester, {
  Size size = const Size(800, 2400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const InterestScreen(),
    ),
  );
}

Future<void> reveal(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder.hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await reveal(tester, field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> openTile(WidgetTester tester, String title) async {
  await reveal(tester, find.text(title));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

Finder stat(String label, String value) => find.descendant(
  of: find.widgetWithText(StatRow, label),
  matching: find.text(value),
);

void main() {
  testWidgets('initial state displays defaults and empty state hint', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Interest Calculator'), findsOneWidget);
    expect(find.text('Simple'), findsOneWidget);
    expect(find.text('Compound'), findsOneWidget);
    expect(fieldText(tester, 'Years'), '10');
    expect(fieldText(tester, 'Months'), '0');
    expect(find.text('Compounding'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);

    expect(
      find.text('Enter a principal and an interest rate to see your results.'),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);
    expect(find.text('Enter a valid amount'), findsNothing);
    expect(find.text('Estimates only — not financial advice.'), findsOneWidget);
  });

  testWidgets(
    'Simple <-> Compound toggle hides and shows Compounding control',
    (tester) async {
      await pumpScreen(tester);
      expect(find.text('Compounding'), findsOneWidget);

      await tester.tap(find.text('Simple'));
      await tester.pumpAndSettle();
      expect(find.text('Compounding'), findsNothing);

      await tester.tap(find.text('Compound'));
      await tester.pumpAndSettle();
      expect(find.text('Compounding'), findsOneWidget);
    },
  );

  testWidgets(
    'INT-1: P 10,000, 5%, 10y, compound monthly, +0 shows golden results',
    (tester) async {
      await pumpScreen(tester);
      await enter(tester, 'Principal', '10000');
      await enter(tester, 'Annual interest rate', '5');

      expect(find.widgetWithText(ResultHero, 'Final balance'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ResultHero),
          matching: find.text(r'$16,470.09'),
        ),
        findsOneWidget,
      );
      expect(stat('Initial principal', r'$10,000.00'), findsOneWidget);
      expect(stat('Total contributions', r'$0.00'), findsOneWidget);
      expect(stat('Total interest', r'$6,470.09'), findsOneWidget);

      expect(find.text('Principal'), findsWidgets);
      expect(find.text('Interest'), findsWidgets);

      expect(find.text('Growth over time'), findsOneWidget);
      expect(find.byType(SimpleLineChart), findsOneWidget);

      expect(find.text('Balance'), findsNothing);
      await openTile(tester, 'Year by year');
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Interest'), findsWidgets);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('* partial year'), findsNothing);
    },
  );

  testWidgets(
    'INT-4: P 10,000, 5%, 10y, simple interest shows golden results',
    (tester) async {
      await pumpScreen(tester);
      await enter(tester, 'Principal', '10000');
      await enter(tester, 'Annual interest rate', '5');

      await tester.tap(find.text('Simple'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ResultHero),
          matching: find.text(r'$15,000.00'),
        ),
        findsOneWidget,
      );
      expect(stat('Initial principal', r'$10,000.00'), findsOneWidget);
      expect(stat('Total interest', r'$5,000.00'), findsOneWidget);
      expect(stat('Total contributions', r'$0.00'), findsOneWidget);
    },
  );

  testWidgets(
    'INT-5: P 10,000, 5%, 10y, compound monthly, +200/month shows golden results',
    (tester) async {
      await pumpScreen(tester);
      await enter(tester, 'Principal', '10000');
      await enter(tester, 'Annual interest rate', '5');
      await enter(tester, 'Monthly contribution (optional)', '200');

      expect(
        find.descendant(
          of: find.byType(ResultHero),
          matching: find.text(r'$47,526.55'),
        ),
        findsOneWidget,
      );
      expect(stat('Initial principal', r'$10,000.00'), findsOneWidget);
      expect(stat('Total contributions', r'$24,000.00'), findsOneWidget);
      expect(stat('Total interest', r'$13,526.55'), findsOneWidget);
    },
  );

  testWidgets(
    'INT-7: partial final year shows asterisk and footnote in table',
    (tester) async {
      await pumpScreen(tester);
      await enter(tester, 'Principal', '1000');
      await enter(tester, 'Annual interest rate', '12');
      await enter(tester, 'Years', '1');
      await enter(tester, 'Months', '6');
      await tester.tap(find.text('Simple'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ResultHero),
          matching: find.text(r'$1,180.00'),
        ),
        findsOneWidget,
      );

      await openTile(tester, 'Year by year');
      final table = find.byType(Table);
      expect(
        find.descendant(of: table, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('2*')),
        findsOneWidget,
      );
      expect(find.text('* partial year'), findsOneWidget);
    },
  );

  testWidgets('compounding dropdown updates results (INT-2, INT-3)', (
    tester,
  ) async {
    await pumpScreen(tester);
    await enter(tester, 'Principal', '10000');
    await enter(tester, 'Annual interest rate', '5');

    // Default monthly: $16,470.09
    expect(find.text(r'$16,470.09'), findsOneWidget);

    // Switch compounding to Annually: INT-2 -> $16,288.95
    await reveal(tester, find.text('Monthly'));
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annually').last);
    await tester.pumpAndSettle();

    expect(find.text(r'$16,288.95'), findsOneWidget);

    // Switch compounding to Daily: INT-3 -> $16,486.65
    await reveal(tester, find.text('Annually'));
    await tester.tap(find.text('Annually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();

    expect(find.text(r'$16,486.65'), findsOneWidget);
  });

  testWidgets('validation messages appear after editing and gate results', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Principal validation
    await enter(tester, 'Principal', '100');
    await enter(tester, 'Annual interest rate', '5');
    expect(find.byType(ResultHero), findsOneWidget);

    await enter(tester, 'Principal', '');
    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(
      find.text('Fix the highlighted fields to see results.'),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);

    await enter(tester, 'Principal', '10000');
    expect(find.text('Enter a valid amount'), findsNothing);
    expect(find.byType(ResultHero), findsOneWidget);

    // Rate validation
    await enter(tester, 'Annual interest rate', '150');
    expect(find.text('Enter a rate between 0 and 100'), findsOneWidget);
    expect(
      find.text('Fix the highlighted fields to see results.'),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);

    await enter(tester, 'Annual interest rate', '5');
    expect(find.text('Enter a rate between 0 and 100'), findsNothing);
    expect(find.byType(ResultHero), findsOneWidget);

    // Term validation: 0 years and 0 months
    await enter(tester, 'Years', '0');
    expect(
      find.text('Enter a term between 1 month and 100 years'),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);

    // Term validation: 101 years
    await enter(tester, 'Years', '101');
    expect(
      find.text('Enter a term between 1 month and 100 years'),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);

    await enter(tester, 'Years', '10');
    expect(
      find.text('Enter a term between 1 month and 100 years'),
      findsNothing,
    );
    expect(find.byType(ResultHero), findsOneWidget);

    // Contribution validation
    await enter(tester, 'Monthly contribution (optional)', '.');
    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.byType(ResultHero), findsNothing);

    await enter(tester, 'Monthly contribution (optional)', '');
    expect(find.text('Enter a valid amount'), findsNothing);
    expect(find.byType(ResultHero), findsOneWidget);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('no overflow at 360x640, text scale $scale', (tester) async {
      await pumpScreen(tester, size: const Size(360, 640), textScale: scale);
      await enter(tester, 'Principal', '100000');
      await enter(tester, 'Annual interest rate', '7.5');
      await enter(tester, 'Years', '30');
      await enter(tester, 'Months', '0');
      await enter(tester, 'Monthly contribution (optional)', '1000');
      await openTile(tester, 'Year by year');

      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 5; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
