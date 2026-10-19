import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/core/theme.dart';
import 'package:moneykit/core/widgets/widgets.dart';
import 'package:moneykit/features/split/split_models.dart';
import 'package:moneykit/features/split/split_screen.dart';
import 'package:moneykit/features/split/split_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 3000),
  double textScale = 1,
  Key? key,
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
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: SplitScreen(key: key, store: SplitStore()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addPerson(WidgetTester tester, String name) async {
  await tester.enterText(find.widgetWithText(TextField, 'Add person'), name);
  await tester.tap(find.byTooltip('Add person'));
  await tester.pumpAndSettle();
}

Future<void> _addPayment(
  WidgetTester tester, {
  required String button,
  required String amount,
  required String payerLabel,
  String? payer,
  String note = '',
}) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
  if (note.isNotEmpty) {
    await tester.enterText(
      find.widgetWithText(TextField, 'Note (optional)'),
      note,
    );
  }
  if (payer != null) {
    await tester.tap(find.text('Unassigned').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(payer).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Finder _hero(String v) =>
    find.descendant(of: find.byType(ResultHero), matching: find.text(v));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('quick split', () {
    Future<void> openQuick(WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.text('Quick split'));
      await tester.pumpAndSettle();
    }

    testWidgets('empty state, then SPL-1 33.33 for 100 / 3', (tester) async {
      await openQuick(tester);
      expect(find.text('Enter a bill amount to split it.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Bill amount'),
        '100',
      );
      await tester.pump();
      expect(_hero('\$33.33'), findsOneWidget);
      expect(find.text('Split by 3 people'), findsOneWidget);
    });

    testWidgets('SST, people stepper and rounding chips', (tester) async {
      await openQuick(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Bill amount'),
        '100',
      );
      await tester.tap(find.byTooltip('More people'));
      await tester.pump();
      await tester.tap(find.text('6% SST'));
      await tester.pump();
      expect(_hero('\$26.50'), findsOneWidget); // 106 / 4
      expect(find.text('Tax / service charge'), findsOneWidget);

      await tester.tap(find.text('16% Combined'));
      await tester.tap(find.byTooltip('Fewer people'));
      await tester.tap(find.text('Round to \$1'));
      await tester.pump();
      expect(_hero('\$39.00'), findsOneWidget); // 116 / 3 = 38.67 -> 39
      expect(find.text('Total after rounding'), findsOneWidget);
    });

    testWidgets('invalid bill shows error and hides result', (tester) async {
      await openQuick(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Bill amount'),
        '0',
      );
      await tester.pump();
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(find.byType(ResultHero), findsNothing);
    });

    testWidgets('people stepper stops at 1', (tester) async {
      await openQuick(tester);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Fewer people'));
        await tester.pump();
      }
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Copy breakdown puts the split on the clipboard', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openQuick(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Bill amount'),
        '100',
      );
      await tester.pump();
      await tester.tap(find.text('Copy breakdown'));
      await tester.pumpAndSettle();
      expect(copied, contains('Per person: \$33.33'));
      expect(find.text('Bill split copied'), findsOneWidget);
    });
  });

  group('settlement', () {
    testWidgets('empty states before any data', (tester) async {
      await _pump(tester);
      expect(
        find.text('No expenses yet. Add what each person paid for.'),
        findsOneWidget,
      );
      expect(
        find.text('No contributions yet. Add money put into the shared kitty.'),
        findsOneWidget,
      );
      expect(
        find.text('Add the people sharing the trip to see who owes whom.'),
        findsOneWidget,
      );
    });

    testWidgets('SPL-4 end to end through the UI', (tester) async {
      await _pump(tester);
      for (final n in ['A', 'B', 'C']) {
        await _addPerson(tester, n);
      }
      await _addPayment(
        tester,
        button: 'Add expense',
        amount: '90',
        payerLabel: 'Paid by',
        payer: 'A',
        note: 'Dinner',
      );
      await _addPayment(
        tester,
        button: 'Add expense',
        amount: '30',
        payerLabel: 'Paid by',
        payer: 'B',
        note: 'Fuel',
      );
      await _addPayment(
        tester,
        button: 'Add contribution',
        amount: '60',
        payerLabel: 'Contributed by',
        payer: 'C',
      );

      expect(_hero('\$60.00'), findsOneWidget);
      expect(find.text('\$180.00'), findsWidgets); // pool
      expect(find.text('+\$30.00 (gets back)'), findsOneWidget);
      expect(find.text('-\$30.00 (owes)'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('Settlement transfers (1)'), findsOneWidget);
      expect(find.text('B → A'), findsOneWidget);
    });

    testWidgets('tapping a transfer marks it paid', (tester) async {
      await _pump(tester);
      await _addPerson(tester, 'A');
      await _addPerson(tester, 'B');
      await _addPayment(
        tester,
        button: 'Add expense',
        amount: '50',
        payerLabel: 'Paid by',
        payer: 'A',
      );
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      await tester.tap(find.text('B → A'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('amount validation in the sheet', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(find.text('Add expense'), findsWidgets); // sheet title still open
    });

    testWidgets('edit and delete a payment; removing a person unassigns', (
      tester,
    ) async {
      await _pump(tester);
      await _addPerson(tester, 'A');
      await _addPerson(tester, 'B');
      await _addPayment(
        tester,
        button: 'Add expense',
        amount: '50',
        payerLabel: 'Paid by',
        payer: 'A',
        note: 'Taxi',
      );
      expect(find.text('Taxi'), findsOneWidget);

      await tester.tap(find.text('Taxi'));
      await tester.pumpAndSettle();
      expect(find.text('Edit expense'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '70');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('\$70.00'), findsWidgets);

      await tester.tap(find.byTooltip('Remove A'));
      await tester.pumpAndSettle();
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('Taxi'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete expense'));
      await tester.pumpAndSettle();
      expect(find.text('Taxi'), findsNothing);
    });

    testWidgets('data persists across screens until Reset > Clear', (
      tester,
    ) async {
      await _pump(tester);
      await _addPerson(tester, 'A');
      await _addPayment(
        tester,
        button: 'Add expense',
        amount: '12',
        payerLabel: 'Paid by',
        payer: 'A',
        note: 'Snacks',
      );

      final saved = (await tester.runAsync(() => SplitStore().load()))!;
      expect(saved.people.single.name, 'A');
      expect(saved.expenses.single.amount, 12);

      await _pump(tester, key: UniqueKey());
      expect(find.text('Snacks'), findsOneWidget);

      await tester.tap(find.byTooltip('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsOneWidget);

      await tester.tap(find.byTooltip('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsNothing);
      expect(await tester.runAsync(() => SplitStore().load()), isNull);
    });

    testWidgets('Copy summary copies the settlement', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester);
      await _addPerson(tester, 'A');
      await _addPerson(tester, 'B');
      await _addPayment(
        tester,
        button: 'Add expense',
        amount: '50',
        payerLabel: 'Paid by',
        payer: 'A',
      );
      await tester.tap(find.text('Copy summary'));
      await tester.pumpAndSettle();
      expect(copied, contains('1. B pays A: \$25.00'));
    });
  });

  group('store', () {
    test('corrupt data loads as null', () async {
      SharedPreferences.setMockInitialValues({
        'split_state_v1': '{"people": 3}',
      });
      expect(await SplitStore().load(), isNull);
      SharedPreferences.setMockInitialValues({'split_state_v1': 'nope'});
      expect(await SplitStore().load(), isNull);
    });

    test('round trip', () async {
      final s = SplitStore();
      await s.save(
        const SplitState(
          people: [Person(id: 1, name: 'A')],
          expenses: [Payment(id: 2, amount: 5.5, payerId: 1, note: 'x')],
          funds: [Payment(id: 3, amount: 9)],
          nextId: 4,
        ),
      );
      final l = (await s.load())!;
      expect(l.expenses.single.note, 'x');
      expect(l.funds.single.payerId, isNull);
      expect(l.nextId, 4);
    });
  });

  testWidgets('no overflow at 360x640 with 1.5x text (both modes)', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 640), textScale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Quick split'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Bill amount'),
      '123.45',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
