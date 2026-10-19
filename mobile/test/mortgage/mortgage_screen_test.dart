import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/core/theme.dart';
import 'package:moneykit/core/widgets/widgets.dart';
import 'package:moneykit/features/mortgage/mortgage_screen.dart';

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
      home: const MortgageScreen(),
    ),
  );
}

Future<void> reveal(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await reveal(tester, field);
  await tester.enterText(field, text);
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
  testWidgets('empty state on start with default 25y term and no errors', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Mortgage Calculator'), findsOneWidget);
    expect(find.text('Loan amount'), findsWidgets);
    expect(find.text('Property price'), findsOneWidget);
    expect(fieldText(tester, 'Loan term (years)'), '25');
    expect(
      find.text(
        'Enter a loan amount and an interest rate to see your monthly payment.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);
    expect(find.text('Enter a valid amount'), findsNothing);
    expect(find.text('Estimates only — not financial advice.'), findsOneWidget);
  });

  testWidgets('golden MTG-1: 500k @ 4% over 25y', (tester) async {
    await pumpScreen(tester);

    await enter(tester, 'Loan amount', '500000');
    await enter(tester, 'Annual interest rate', '4');

    expect(find.widgetWithText(ResultHero, 'Monthly payment'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResultHero),
        matching: find.text('\$2,639.18'),
      ),
      findsOneWidget,
    );

    expect(stat('Loan amount', '\$500,000.00'), findsOneWidget);
    expect(stat('Total interest', '\$291,755.26'), findsOneWidget);
    expect(stat('Total paid', '\$791,755.26'), findsOneWidget);
    expect(stat('Loan term', '25 yrs 0 mo'), findsOneWidget);

    // With extra payments card must NOT be present when extra = 0
    expect(find.text('With extra payments'), findsNothing);

    // Principal vs Interest SplitBar
    expect(find.text('Principal'), findsWidgets);
    expect(find.text('Interest'), findsWidgets);

    // Amortisation schedule
    expect(find.text('Amortisation schedule'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
  });

  testWidgets('golden MTG-2: 500k @ 4% 25y with extra 500', (tester) async {
    await pumpScreen(tester);

    await enter(tester, 'Loan amount', '500000');
    await enter(tester, 'Annual interest rate', '4');
    await enter(tester, 'Extra monthly payment (optional)', '500');

    expect(
      find.descendant(
        of: find.byType(ResultHero),
        matching: find.text('\$2,639.18'),
      ),
      findsOneWidget,
    );

    // With extra payments card present
    expect(find.text('With extra payments'), findsOneWidget);
    expect(stat('Time saved', '6 yrs 0 mo'), findsOneWidget);
    expect(stat('Interest saved', '\$77,667.69'), findsOneWidget);
    expect(stat('Total interest', '\$214,087.57'), findsOneWidget);
    // Summary reflects the accelerated plan, consistently with the totals.
    expect(stat('Loan term', '19 yrs 0 mo'), findsOneWidget);
  });

  testWidgets(
    'property price mode: \$500,000 price, 20% down => loan \$400,000.00 caption',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Property price'));
      await tester.pumpAndSettle();

      await enter(tester, 'Property price', '500000');
      await enter(tester, 'Down payment', '20');

      expect(find.text('Loan amount: \$400,000.00'), findsOneWidget);

      await enter(tester, 'Annual interest rate', '4');

      expect(
        find.descendant(
          of: find.byType(ResultHero),
          matching: find.text('\$2,111.35'),
        ),
        findsOneWidget,
      );
      expect(stat('Loan amount', '\$400,000.00'), findsOneWidget);
    },
  );

  testWidgets('validation messages appear after typing and gate the results', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Invalid loan amount
    await enter(tester, 'Loan amount', '0');
    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(
      find.text('Fix the highlighted fields to see results.'),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);

    await enter(tester, 'Loan amount', '500000');
    expect(find.text('Enter a valid amount'), findsNothing);

    // Rate validation
    await enter(tester, 'Annual interest rate', '35');
    expect(find.text('Enter a rate between 0 and 30'), findsOneWidget);
    expect(
      find.text('Fix the highlighted fields to see results.'),
      findsOneWidget,
    );
    await enter(tester, 'Annual interest rate', '');
    expect(find.text('Enter a rate between 0 and 30'), findsOneWidget);
    await enter(tester, 'Annual interest rate', '4');
    expect(find.text('Enter a rate between 0 and 30'), findsNothing);
    expect(find.byType(ResultHero), findsOneWidget);

    // Term validation
    await enter(tester, 'Loan term (years)', '0');
    expect(find.text('Enter a term between 1 and 40 years'), findsOneWidget);
    expect(find.byType(ResultHero), findsNothing);
    await enter(tester, 'Loan term (years)', '45');
    expect(find.text('Enter a term between 1 and 40 years'), findsOneWidget);
    await enter(tester, 'Loan term (years)', '2.5');
    expect(find.text('Enter a term between 1 and 40 years'), findsOneWidget);
    await enter(tester, 'Loan term (years)', '25');
    expect(find.text('Enter a term between 1 and 40 years'), findsNothing);
    expect(find.byType(ResultHero), findsOneWidget);

    // Extra payment validation
    await enter(tester, 'Extra monthly payment (optional)', '.');
    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.byType(ResultHero), findsNothing);
    await enter(tester, 'Extra monthly payment (optional)', '');
    expect(find.text('Enter a valid amount'), findsNothing);
    expect(find.byType(ResultHero), findsOneWidget);

    // Property price mode validation
    await tester.tap(find.text('Property price'));
    await tester.pumpAndSettle();

    await enter(tester, 'Property price', '500000');
    await enter(tester, 'Down payment', '100');
    expect(
      find.text('Down payment must be less than the price'),
      findsOneWidget,
    );
    expect(find.byType(ResultHero), findsNothing);

    // Switch down payment to dollar mode
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<DownPaymentType>),
        matching: find.text(r'$'),
      ),
    );
    await tester.pumpAndSettle();

    await enter(tester, 'Down payment', '500000');
    expect(
      find.text('Down payment must be less than the price'),
      findsOneWidget,
    );

    await enter(tester, 'Down payment', '100000');
    expect(find.text('Down payment must be less than the price'), findsNothing);
    expect(find.text('Loan amount: \$400,000.00'), findsOneWidget);
    expect(find.byType(ResultHero), findsOneWidget);
  });

  testWidgets(
    'schedule toggle shows Yearly header Year then Monthly header #',
    (tester) async {
      await pumpScreen(tester);
      await enter(tester, 'Loan amount', '500000');
      await enter(tester, 'Annual interest rate', '4');

      await reveal(tester, find.text('Amortisation schedule'));
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Principal'), findsWidgets);
      expect(find.text('Interest'), findsWidgets);
      expect(find.text('Balance'), findsWidgets);

      // Toggle to Monthly
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('Year'), findsNothing);
      expect(find.text('#'), findsOneWidget);

      // Toggle back to Yearly
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      expect(find.text('Year'), findsOneWidget);
      expect(find.text('#'), findsNothing);
    },
  );

  for (final scale in [1.0, 1.5]) {
    testWidgets('no overflow at 360x640, text scale $scale', (tester) async {
      await pumpScreen(tester, size: const Size(360, 640), textScale: scale);
      await enter(tester, 'Loan amount', '500000');
      await enter(tester, 'Annual interest rate', '4');
      await enter(tester, 'Extra monthly payment (optional)', '500');

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'property price mode no overflow at 360x640, text scale $scale',
      (tester) async {
        await pumpScreen(tester, size: const Size(360, 640), textScale: scale);
        await tester.tap(find.text('Property price'));
        await tester.pumpAndSettle();
        await enter(tester, 'Property price', '500000');
        await enter(tester, 'Down payment', '20');
        await enter(tester, 'Annual interest rate', '4');

        expect(tester.takeException(), isNull);
      },
    );
  }
}
