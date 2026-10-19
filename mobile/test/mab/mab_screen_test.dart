import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/core/theme.dart';
import 'package:moneykit/core/widgets/widgets.dart';
import 'package:moneykit/features/mab/mab_screen.dart';
import 'package:moneykit/features/mab/mab_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _balancesCsv =
    'Account,Date,Balance\n'
    '"Start Amount","1 April, 2025",500.00\n'
    '"Transfer","30 April, 2025",150.00\n'
    '"Food","30 April, 2025",-3.00\n';

const _outsideCycleCsv =
    'Account,Date,Balance\n'
    '"Start Amount","1 April, 2025",100.00\n'
    '"Salary","5 May, 2025",50.00\n';

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
      home: MabScreen(key: key, store: MabStore()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _importCsv(WidgetTester tester, String csv) async {
  await tester.tap(find.byTooltip('Import CSV'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Paste CSV'), csv);
  await tester.tap(find.text('Import'));
  await tester.pumpAndSettle();
}

Finder _hero(String value) =>
    find.descendant(of: find.byType(ResultHero), matching: find.text(value));

Finder _balanceField() => find.widgetWithText(TextField, 'Opening balance');

String _fieldText(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).controller!.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('empty and validation', () {
    testWidgets('shows empty states before any input', (tester) async {
      await _pump(tester);
      expect(find.text('MAB Calculator'), findsOneWidget);
      expect(
        find.text(
          'Enter an opening balance to see your Monthly Average Balance.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No transactions yet. Add deposits and withdrawals made during the month.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enter a valid amount'), findsNothing);
      expect(find.byType(ResultHero), findsNothing);
    });

    testWidgets('typing a balance shows the hero live', (tester) async {
      await _pump(tester);
      await tester.enterText(_balanceField(), '1,000.50');
      await tester.pump();
      expect(_hero('\$1,000.50'), findsOneWidget);
      expect(find.text('Monthly Average Balance'), findsOneWidget);

      await tester.enterText(_balanceField(), '-200');
      await tester.pump();
      expect(_hero('-\$200.00'), findsOneWidget);
    });

    testWidgets(
      'invalid balance shows the error and the fix hint, not stale numbers',
      (tester) async {
        await _pump(tester);
        await tester.enterText(_balanceField(), '500');
        await tester.pump();
        await tester.enterText(_balanceField(), '-');
        await tester.pump();
        expect(find.text('Enter a valid amount'), findsOneWidget);
        expect(
          find.text('Fix the highlighted fields to see results.'),
          findsOneWidget,
        );
        expect(find.byType(ResultHero), findsNothing);

        await tester.enterText(_balanceField(), '');
        await tester.pump();
        expect(find.text('Enter a valid amount'), findsOneWidget);
      },
    );

    testWidgets('summary rows for a balance with no transactions', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(_balanceField(), '250');
      await tester.pump();
      expect(find.text('Lowest daily balance'), findsOneWidget);
      expect(find.text('Highest daily balance'), findsOneWidget);
      expect(find.text('Days in cycle'), findsOneWidget);
      expect(find.text('Transactions counted'), findsOneWidget);
      expect(find.text('Daily balance'), findsOneWidget);
    });
  });

  group('CSV import (MAB-1 golden flow)', () {
    testWidgets('transactions render as a table: header, rows by date', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Name'), findsNothing);
      await _importCsv(
        tester,
        'Account,Date,Balance\n'
        '"Start Amount","1 April, 2025",500.00\n'
        '"Food","20 April, 2025",-3.00\n'
        '"Transfer","5 April, 2025",150.00\n',
      );
      for (final h in ['Date', 'Name', 'Amount']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      expect(find.text('+\$150.00'), findsOneWidget);
      expect(find.text('-\$3.00'), findsOneWidget);
      final transferY = tester.getTopLeft(find.text('Transfer')).dy;
      final foodY = tester.getTopLeft(find.text('Food')).dy;
      expect(transferY, lessThan(foodY));
      expect(
        tester.getTopLeft(find.text('5 Apr 2025')).dx,
        tester.getTopLeft(find.text('20 Apr 2025')).dx,
      );
    });

    testWidgets('balances.csv gives 504.90, 647.00 high, 500.00 low', (
      tester,
    ) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);

      expect(_hero('\$504.90'), findsOneWidget);
      expect(find.text('Imported 2 transactions'), findsOneWidget);
      expect(find.text('\$647.00'), findsOneWidget);
      expect(find.text('\$500.00'), findsOneWidget);
      expect(
        find.text('Billing cycle: 1 Apr 2025 – 30 Apr 2025 (30 days)'),
        findsOneWidget,
      );
      expect(_fieldText(tester, _balanceField()), '500');
      expect(find.text('+\$150.00'), findsOneWidget);
      expect(find.text('-\$3.00'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Daily balances (30 days)'), findsOneWidget);
      expect(
        find.text('1 Apr 2025'),
        findsOneWidget,
        reason: 'daily list is collapsed',
      );
    });

    testWidgets('daily list expands', (tester) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.tap(find.text('Daily balances (30 days)'));
      await tester.pumpAndSettle();
      expect(find.text('1 Apr 2025'), findsNWidgets(2));
      expect(find.text('30 Apr 2025'), findsNWidgets(3));
    });

    testWidgets('bad rows show errors and import nothing', (tester) async {
      await _pump(tester);
      await _importCsv(
        tester,
        'Account,Date,Balance\n"Start","1 April, 2025",500\n"Bad","abc",5\n',
      );
      expect(find.text('Import from CSV'), findsOneWidget);
      expect(find.text("Row 3: invalid date 'abc'"), findsOneWidget);
      expect(find.byType(ResultHero), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Import from CSV'), findsNothing);
      expect(_fieldText(tester, _balanceField()), '');
    });

    testWidgets('empty paste reports an error', (tester) async {
      await _pump(tester);
      await _importCsv(tester, '');
      expect(find.text('No data found'), findsOneWidget);
    });

    testWidgets('single transaction message is singular', (tester) async {
      await _pump(tester);
      await _importCsv(tester, _outsideCycleCsv);
      expect(find.text('Imported 1 transaction'), findsOneWidget);
    });

    testWidgets('transactions outside the cycle are listed in the banner', (
      tester,
    ) async {
      await _pump(tester);
      await _importCsv(tester, _outsideCycleCsv);
      expect(
        find.text(
          '1 transaction is outside the billing cycle and was ignored: '
          'Salary (5 May 2025)',
        ),
        findsOneWidget,
      );
      expect(_hero('\$100.00'), findsOneWidget);
    });

    testWidgets('banner is plural-aware', (tester) async {
      await _pump(tester);
      await _importCsv(tester, '$_outsideCycleCsv"Gift","2 June, 2025",10\n');
      expect(
        find.text(
          '2 transactions are outside the billing cycle and were ignored: '
          'Salary (5 May 2025), Gift (2 Jun 2025)',
        ),
        findsOneWidget,
      );
    });
  });

  group('transactions', () {
    testWidgets('add a deposit with a blank name, then delete it', (
      tester,
    ) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);

      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsNWidgets(2));
      expect(find.text('Deposit'), findsOneWidget);
      expect(find.text('Withdrawal'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '100');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction'), findsOneWidget);
      expect(find.text('+\$100.00'), findsOneWidget);
      expect(_hero('\$604.90'), findsOneWidget);

      // Sorted by date: the 1 Apr deposit is the first row.
      await tester.tap(find.byTooltip('Delete transaction').first);
      await tester.pumpAndSettle();
      expect(find.text('Transaction'), findsNothing);
      expect(_hero('\$504.90'), findsOneWidget);
    });

    testWidgets('add a named withdrawal', (tester) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdrawal'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Rent');
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '10');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('-\$10.00'), findsOneWidget);
      expect(find.text('Transactions counted'), findsOneWidget);
    });

    testWidgets('tapping a row edits it', (tester) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(find.text('Edit transaction'), findsOneWidget);
      expect(_fieldText(tester, find.widgetWithText(TextField, 'Amount')), '3');
      expect(
        _fieldText(tester, find.widgetWithText(TextField, 'Name')),
        'Food',
      );

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('-\$5.00'), findsOneWidget);
      expect(find.text('-\$3.00'), findsNothing);
      expect(_hero('\$504.83'), findsOneWidget);
    });

    testWidgets('sheet validates the amount', (tester) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(find.text('Edit transaction'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(
        find.text('Add transaction'),
        findsNWidgets(2),
        reason: 'sheet stays open',
      );
    });

    testWidgets('sheet rejects a date outside the billing cycle', (
      tester,
    ) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '20');

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(DateField),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('5'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('5 May 2025'), findsOneWidget);
      expect(
        find.text('Date must be within the billing cycle'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add transaction'),
        findsNWidgets(2),
        reason: 'sheet stays open',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsOneWidget);
      expect(_hero('\$504.90'), findsOneWidget);
    });

    testWidgets('cancel discards the sheet', (tester) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '100');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_hero('\$504.90'), findsOneWidget);
    });
  });

  group('reset', () {
    testWidgets('cancel keeps data, clear wipes screen and store', (
      tester,
    ) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);

      await tester.tap(find.byTooltip('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all data?'), findsOneWidget);
      expect(
        find.text('This removes the opening balance and all transactions.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_hero('\$504.90'), findsOneWidget);

      await tester.tap(find.byTooltip('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultHero), findsNothing);
      expect(
        find.text(
          'Enter an opening balance to see your Monthly Average Balance.',
        ),
        findsOneWidget,
      );
      expect(find.text('Transfer'), findsNothing);
      expect(_fieldText(tester, _balanceField()), '');
      expect(await tester.runAsync(() => MabStore().load()), isNull);
    });
  });

  group('persistence', () {
    testWidgets('changes are saved and restored by a new screen', (
      tester,
    ) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);

      final saved = (await tester.runAsync(() => MabStore().load()))!;
      expect(saved.openingBalance, 500);
      expect(saved.openingDate, DateTime(2025, 4, 1));
      expect(saved.transactions.length, 2);

      await _pump(tester, key: UniqueKey());
      expect(_fieldText(tester, _balanceField()), '500');
      expect(_hero('\$504.90'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('typing and deleting are saved', (tester) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.enterText(_balanceField(), '600');
      await tester.pump();
      await tester.tap(find.byTooltip('Delete transaction').first);
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => MabStore().load()))!;
      expect(saved.openingBalance, 600);
      expect(saved.transactions.length, 1);
    });

    testWidgets('edits made with a blank balance are kept until Reset', (
      tester,
    ) async {
      await _pump(tester);
      await _importCsv(tester, _balancesCsv);
      await tester.enterText(_balanceField(), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Delete transaction').first);
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => MabStore().load()))!;
      expect(saved.openingBalance, isNull);
      expect(saved.transactions.length, 1);

      await _pump(tester, key: UniqueKey());
      expect(_fieldText(tester, _balanceField()), '');
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('restores a stored session on launch', (tester) async {
      SharedPreferences.setMockInitialValues({
        'mab_state_v1': jsonEncode({
          'openingBalance': 250.5,
          'openingDate': '2025-03-15',
          'transactions': [
            {'name': 'Gift', 'date': '2025-03-20', 'amount': 20.0},
          ],
        }),
      });
      await _pump(tester);
      expect(_fieldText(tester, _balanceField()), '250.5');
      expect(
        find.text('Billing cycle: 1 Mar 2025 – 31 Mar 2025 (31 days)'),
        findsOneWidget,
      );
      expect(find.text('Gift'), findsOneWidget);
      expect(find.text('+\$20.00'), findsOneWidget);
    });

    testWidgets('corrupt stored data is ignored', (tester) async {
      SharedPreferences.setMockInitialValues({
        'mab_state_v1': '{"openingBalance": ',
      });
      await _pump(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Enter an opening balance to see your Monthly Average Balance.',
        ),
        findsOneWidget,
      );
      expect(_fieldText(tester, _balanceField()), '');
    });
  });

  group('layout', () {
    for (final scale in [1.0, 1.5]) {
      testWidgets('no overflow at 360x640, text scale $scale', (tester) async {
        await _pump(tester, size: const Size(360, 640), textScale: scale);
        await _importCsv(
          tester,
          '$_balancesCsv"A very long transaction name for a narrow screen",'
          '"12 April, 2025",1234567.89\n',
        );
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        final list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Daily balances (30 days)'),
          300,
          scrollable: list,
        );
        await tester.tap(find.text('Daily balances (30 days)'));
        await tester.pumpAndSettle();
        await tester.drag(list, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(list, const Offset(0, 6000));
        await tester.pumpAndSettle();
        final add = find.widgetWithText(FilledButton, 'Add transaction');
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Import CSV'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Paste CSV'),
          'x',
        );
        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
