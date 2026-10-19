import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/core/theme.dart';
import 'package:moneykit/core/widgets/widgets.dart';
import 'package:moneykit/features/cpf/cpf_screen.dart';

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
      home: const CpfScreen(),
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

Future<void> enterCpf1(WidgetTester tester) async {
  await enter(tester, 'Ordinary Account (OA)', '20000');
  await enter(tester, 'MediSave Account (MA)', '10000');
  await enter(tester, 'Projection years', '1');
}

void main() {
  testWidgets('defaults show a zero result with prefilled rates and years', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('CPF Interest Calculator'), findsOneWidget);
    expect(find.text('Below 55'), findsOneWidget);
    expect(find.text('55 & above'), findsOneWidget);
    expect(fieldText(tester, 'Projection years'), '5');
    expect(
      find.widgetWithText(ResultHero, 'Total CPF balance after 5 years'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ResultHero),
        matching: find.text('\$0.00'),
      ),
      findsOneWidget,
    );
    expect(find.text('Enter a valid amount'), findsNothing);

    await openTile(tester, 'Interest rates (editable)');
    expect(fieldText(tester, 'OA rate'), '2.5');
    expect(fieldText(tester, 'SA/RA rate'), '4');
    expect(fieldText(tester, 'MA rate'), '4');
    expect(
      find.textContaining('Estimates only. Interest is calculated monthly'),
      findsOneWidget,
    );
  });

  testWidgets('CPF-1 below 55, 1 year', (tester) async {
    await pumpScreen(tester);
    await enter(tester, 'Ordinary Account (OA)', '20000');
    await enter(tester, 'Special Account (SA)', '10000');
    await enter(tester, 'MediSave Account (MA)', '10000');
    await enter(tester, 'Projection years', '1');

    expect(
      find.widgetWithText(ResultHero, 'Total CPF balance after 1 year'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ResultHero),
        matching: find.text('\$41,700.00'),
      ),
      findsOneWidget,
    );
    expect(stat('Total interest earned', '\$1,700.00'), findsOneWidget);
    expect(stat('Basic interest', '\$1,300.00'), findsOneWidget);
    expect(stat('Extra interest', '\$400.00'), findsOneWidget);
    expect(stat('Ordinary Account (OA)', '\$20,500.00'), findsOneWidget);
    expect(stat('Special Account (SA)', '\$10,800.00'), findsOneWidget);
    expect(stat('MediSave Account (MA)', '\$10,400.00'), findsOneWidget);
  });

  testWidgets('CPF-3 at 55+ relabels SA to RA and keeps the typed value', (
    tester,
  ) async {
    await pumpScreen(tester);
    await enter(tester, 'Ordinary Account (OA)', '30000');
    await enter(tester, 'Special Account (SA)', '30000');
    await enter(tester, 'MediSave Account (MA)', '10000');
    await enter(tester, 'Projection years', '1');
    await openTile(tester, 'Monthly contributions (optional)');
    expect(find.widgetWithText(TextField, 'SA contribution'), findsOneWidget);

    await tester.tap(find.text('55 & above'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Special Account (SA)'),
      findsNothing,
    );
    expect(fieldText(tester, 'Retirement Account (RA)'), '30000');
    expect(find.widgetWithText(TextField, 'SA contribution'), findsNothing);
    expect(find.widgetWithText(TextField, 'RA contribution'), findsOneWidget);
    expect(stat('Total interest earned', '\$3,250.00'), findsOneWidget);
    expect(stat('Retirement Account (RA)', '\$32,100.00'), findsOneWidget);
    expect(stat('Ordinary Account (OA)', '\$30,750.00'), findsOneWidget);
    expect(stat('MediSave Account (MA)', '\$10,400.00'), findsOneWidget);

    await tester.tap(find.text('Below 55'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Special Account (SA)'),
      findsOneWidget,
    );
    expect(fieldText(tester, 'Special Account (SA)'), '30000');
  });

  testWidgets('monthly contributions feed the projection (CPF-4)', (
    tester,
  ) async {
    await pumpScreen(tester);
    await enter(tester, 'Projection years', '1');
    await openTile(tester, 'Monthly contributions (optional)');
    await enter(tester, 'OA contribution', '1000');

    expect(stat('Total interest earned', '\$192.50'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResultHero),
        matching: find.text('\$12,192.50'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'editing a rate changes the result and Reset to defaults restores it',
    (tester) async {
      await pumpScreen(tester);
      await enterCpf1(tester);
      await enter(tester, 'Special Account (SA)', '10000');
      expect(stat('Total interest earned', '\$1,700.00'), findsOneWidget);

      await openTile(tester, 'Interest rates (editable)');
      await enter(tester, 'OA rate', '5');
      expect(stat('Total interest earned', '\$2,200.00'), findsOneWidget);

      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'OA rate'), '2.5');
      expect(stat('Total interest earned', '\$1,700.00'), findsOneWidget);
    },
  );

  testWidgets('validation messages appear after typing and gate the results', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openTile(tester, 'Interest rates (editable)');
    await openTile(tester, 'Monthly contributions (optional)');

    for (final bad in ['0', '41', '2.5']) {
      await enter(tester, 'Projection years', bad);
      expect(find.text('Enter 1 to 40 years'), findsOneWidget, reason: bad);
      expect(
        find.text('Fix the highlighted fields to see results.'),
        findsOneWidget,
      );
      expect(find.byType(ResultHero), findsNothing);
    }
    await enter(tester, 'Projection years', '40');
    expect(find.text('Enter 1 to 40 years'), findsNothing);
    expect(find.byType(ResultHero), findsOneWidget);

    await enter(tester, 'OA rate', '11');
    expect(find.text('Enter a rate between 0 and 10'), findsOneWidget);
    await enter(tester, 'OA rate', '');
    expect(find.text('Enter a rate between 0 and 10'), findsOneWidget);
    await enter(tester, 'OA rate', '10');
    expect(find.text('Enter a rate between 0 and 10'), findsNothing);

    await enter(tester, 'Ordinary Account (OA)', '1.2.3');
    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.byType(ResultHero), findsNothing);
    await enter(tester, 'Ordinary Account (OA)', '');
    expect(find.text('Enter a valid amount'), findsNothing);

    await enter(tester, 'OA contribution', '.');
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('year-by-year table is collapsed and lists each year', (
    tester,
  ) async {
    await pumpScreen(tester);
    await enter(tester, 'Ordinary Account (OA)', '20000');
    await enter(tester, 'Projection years', '2');

    expect(find.text('Total balance'), findsNothing);
    await openTile(tester, 'Year by year');
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Interest'), findsOneWidget);
    expect(find.text('Total balance'), findsOneWidget);
    final table = find.byType(Table);
    expect(
      find.descendant(of: table, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('2')),
      findsOneWidget,
    );
    expect(find.text('\$700.00'), findsWidgets);
    expect(find.text('\$20,700.00'), findsWidgets);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('no overflow at 360x640, text scale $scale', (tester) async {
      await pumpScreen(tester, size: const Size(360, 640), textScale: scale);
      await tester.tap(find.text('55 & above'));
      await tester.pumpAndSettle();
      await enter(tester, 'Ordinary Account (OA)', '123456789.12');
      await openTile(tester, 'Monthly contributions (optional)');
      await openTile(tester, 'Interest rates (editable)');
      await enter(tester, 'Projection years', '40');
      await openTile(tester, 'Year by year');

      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
