import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/features/mab/mab_csv.dart';
import 'package:moneykit/features/mab/mab_engine.dart';
import 'package:moneykit/features/mab/mab_models.dart';

MabTransaction tx(String name, DateTime date, double amount) =>
    MabTransaction(name: name, date: date, amount: amount);

void main() {
  test('MAB-1: balances.csv golden vector', () {
    final parsed = parseMabCsv(
      'Account,Date,Balance\n'
      '"Start Amount","1 April, 2025",500.00\n'
      '"Transfer","30 April, 2025",150.00\n'
      '"Food","30 April, 2025",-3.00\n',
    );
    expect(parsed.errors, isEmpty);
    final r = calculateMab(parsed.input!);
    expect(r.cycleStart, DateTime(2025, 4, 1));
    expect(r.cycleEnd, DateTime(2025, 4, 30));
    expect(r.days, 30);
    expect(r.daily.first.balance, closeTo(500, 1e-2));
    expect(r.daily[28].balance, closeTo(500, 1e-2));
    expect(r.daily.last.balance, closeTo(647, 1e-2));
    expect(r.mab, closeTo(504.90, 1e-2));
    expect(r.minBalance, closeTo(500, 1e-2));
    expect(r.maxBalance, closeTo(647, 1e-2));
    expect(r.ignored, isEmpty);
    expect(r.countedTransactions, 2);
  });

  test('MAB-2: no transactions, 31-day month', () {
    final r = calculateMab(
      MabInput(openingBalance: 1000, openingDate: DateTime(2025, 3, 15)),
    );
    expect(r.days, 31);
    expect(r.cycleStart, DateTime(2025, 3, 1));
    expect(r.cycleEnd, DateTime(2025, 3, 31));
    expect(r.mab, closeTo(1000, 1e-2));
    expect(r.countedTransactions, 0);
  });

  test('MAB-3: leap-year February', () {
    final r = calculateMab(
      MabInput(
        openingBalance: 1000,
        openingDate: DateTime(2024, 2, 1),
        transactions: [tx('Rent', DateTime(2024, 2, 15), -500)],
      ),
    );
    expect(r.days, 29);
    expect(r.cycleEnd, DateTime(2024, 2, 29));
    expect(r.mab, closeTo((14 * 1000 + 15 * 500) / 29, 1e-6));
  });

  test('non-leap February has 28 days', () {
    final r = calculateMab(
      MabInput(openingBalance: 10, openingDate: DateTime(2025, 2, 10)),
    );
    expect(r.days, 28);
  });

  test('MAB-4: out-of-cycle transaction is ignored and reported', () {
    final late = tx('Late', DateTime(2025, 5, 5), 50);
    final r = calculateMab(
      MabInput(
        openingBalance: 100,
        openingDate: DateTime(2025, 4, 1),
        transactions: [late],
      ),
    );
    expect(r.mab, closeTo(100, 1e-2));
    expect(r.ignored, [late]);
    expect(r.countedTransactions, 0);
  });

  test('same day-of-month in another month or year is ignored', () {
    final r = calculateMab(
      MabInput(
        openingBalance: 100,
        openingDate: DateTime(2025, 4, 1),
        transactions: [
          tx('Prev year', DateTime(2024, 4, 5), 50),
          tx('Prev month', DateTime(2025, 3, 5), 50),
        ],
      ),
    );
    expect(r.mab, closeTo(100, 1e-2));
    expect(r.ignored, hasLength(2));
  });

  test('MAB-5: negative opening, day-1 transaction applies on day 1', () {
    final r = calculateMab(
      MabInput(
        openingBalance: -200,
        openingDate: DateTime(2025, 1, 1),
        transactions: [tx('Salary', DateTime(2025, 1, 1), 300)],
      ),
    );
    expect(r.days, 31);
    expect(r.daily.first.balance, closeTo(100, 1e-2));
    expect(r.mab, closeTo(100, 1e-2));
    expect(r.minBalance, closeTo(100, 1e-2));
    expect(r.maxBalance, closeTo(100, 1e-2));
  });

  test('MAB-6: input order does not matter, same-day txs accumulate', () {
    final a = tx('A', DateTime(2025, 6, 10), 200);
    final b = tx('B', DateTime(2025, 6, 10), -50);
    final c = tx('C', DateTime(2025, 6, 3), 100);
    MabResult run(List<MabTransaction> txs) => calculateMab(
      MabInput(
        openingBalance: 1000,
        openingDate: DateTime(2025, 6, 1),
        transactions: txs,
      ),
    );
    final r1 = run([a, b, c]);
    final r2 = run([c, b, a]);
    final r3 = run([b, a, c]);
    expect(r2.mab, closeTo(r1.mab, 1e-9));
    expect(r3.mab, closeTo(r1.mab, 1e-9));
    // 2 days @1000, 7 days @1100, 21 days @1250.
    expect(r1.mab, closeTo((2 * 1000 + 7 * 1100 + 21 * 1250) / 30, 1e-6));
    expect(r1.daily[9].balance, closeTo(1250, 1e-9));
    expect(r1.countedTransactions, 3);
  });

  test('December cycle has 31 days and does not roll into January', () {
    final r = calculateMab(
      MabInput(
        openingBalance: 100,
        openingDate: DateTime(2025, 12, 20),
        transactions: [
          tx('Dec 31', DateTime(2025, 12, 31), 100),
          tx('Jan 1', DateTime(2026, 1, 1), 1000),
        ],
      ),
    );
    expect(r.cycleStart, DateTime(2025, 12, 1));
    expect(r.cycleEnd, DateTime(2025, 12, 31));
    expect(r.days, 31);
    expect(r.daily.last.date, DateTime(2025, 12, 31));
    expect(r.daily.last.balance, closeTo(200, 1e-2));
    expect(r.mab, closeTo((30 * 100 + 200) / 31, 1e-6));
    expect(r.ignored.single.name, 'Jan 1');
  });

  test('daily dates are consecutive calendar days', () {
    final r = calculateMab(
      MabInput(openingBalance: 0, openingDate: DateTime(2025, 3, 15)),
    );
    for (var i = 0; i < r.daily.length; i++) {
      expect(r.daily[i].date, DateTime(2025, 3, i + 1));
    }
  });
}
