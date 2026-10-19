import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/features/mortgage/mortgage_engine.dart';
import 'package:moneykit/features/mortgage/mortgage_models.dart';

MortgageInput _input(
  double loan,
  double rate,
  int years, {
  double extra = 0,
  DateTime? start,
}) => MortgageInput(
  loanAmount: loan,
  annualRatePercent: rate,
  termYears: years,
  extraMonthlyPayment: extra,
  startDate: start ?? DateTime(2025, 1, 1),
);

void main() {
  group('golden vectors', () {
    test('MTG-1: 500k @ 4% over 25y', () {
      final res = calculateMortgage(_input(500000, 4, 25));
      expect(res.monthlyPayment, closeTo(2639.18, 0.01));
      expect(res.totalInterest, closeTo(291755.26, 1.0));
      expect(res.totalPaid, closeTo(791755.26, 1.0));
      expect(res.monthsToPayoff, 300);
      expect(res.schedule.length, 300);
    });

    test('MTG-2: extra 500 pays off in 228 months', () {
      final res = calculateMortgage(_input(500000, 4, 25, extra: 500));
      expect(res.monthlyPayment, closeTo(2639.18, 0.01));
      expect(res.monthsToPayoff, 228);
      expect(res.totalInterest, closeTo(214087.57, 1.0));
      expect(res.monthsSaved, 72);
      expect(res.interestSaved, closeTo(77667.69, 1.0));
      expect(res.baselineMonths, 300);
    });

    test('MTG-3: 0% rate splits the loan evenly', () {
      final res = calculateMortgage(_input(120000, 0, 10));
      expect(res.monthlyPayment, closeTo(1000.0, 0.01));
      expect(res.totalInterest, closeTo(0.0, 0.01));
      expect(res.monthsToPayoff, 120);
      expect(res.schedule.last.balance, 0.0);
    });

    test('MTG-4: 1y loan has 12 rows ending at exactly 0', () {
      final res = calculateMortgage(_input(100000, 3, 1));
      expect(res.schedule.length, 12);
      expect(res.schedule.last.balance, 0.0);
    });
  });

  group('invariants', () {
    test('principal sums to the loan amount', () {
      for (final extra in [0.0, 500.0]) {
        final res = calculateMortgage(_input(500000, 4, 25, extra: extra));
        final principal = res.schedule.fold(0.0, (a, r) => a + r.principal);
        expect(principal, closeTo(500000, 0.01));
      }
    });

    test('totals equal the schedule sums', () {
      final res = calculateMortgage(_input(250000, 3.5, 20, extra: 200));
      expect(
        res.totalPaid,
        closeTo(res.schedule.fold(0.0, (a, r) => a + r.payment), 1e-6),
      );
      expect(res.totalPaid - res.totalInterest, closeTo(250000, 0.01));
    });

    test('balance is never negative and strictly decreasing', () {
      final res = calculateMortgage(_input(500000, 4, 25, extra: 500));
      var prev = 500000.0;
      for (final row in res.schedule) {
        expect(row.balance, greaterThanOrEqualTo(0));
        expect(row.balance, lessThan(prev));
        prev = row.balance;
      }
      expect(prev, 0.0);
    });

    test('row dates advance one month, rolling over the year', () {
      final res = calculateMortgage(
        _input(100000, 3, 1, start: DateTime(2025, 11, 15)),
      );
      expect(res.schedule.first.date, DateTime(2025, 12, 1));
      expect(res.schedule[1].date, DateTime(2026, 1, 1));
      expect(res.schedule.last.date, DateTime(2026, 11, 1));
      for (var i = 1; i < res.schedule.length; i++) {
        final a = res.schedule[i - 1].date;
        final b = res.schedule[i].date;
        expect((b.year * 12 + b.month) - (a.year * 12 + a.month), 1);
      }
      expect(res.payoffDate, res.schedule.last.date);
    });

    test('rows are numbered from 1', () {
      final res = calculateMortgage(_input(100000, 3, 1));
      expect(res.schedule.map((r) => r.month), List.generate(12, (i) => i + 1));
    });

    test('monthsSaved is baseline minus actual', () {
      final res = calculateMortgage(_input(300000, 5, 30, extra: 300));
      expect(res.monthsSaved, res.baselineMonths - res.monthsToPayoff);
      expect(res.monthsSaved, greaterThan(0));
      expect(res.interestSaved, greaterThan(0));
    });

    test('no extra means nothing saved', () {
      final res = calculateMortgage(_input(500000, 4, 25));
      expect(res.interestSaved, 0.0);
      expect(res.monthsSaved, 0);
      expect(res.baselineMonths, res.monthsToPayoff);
    });

    test('a very large extra pays off in one month', () {
      final res = calculateMortgage(_input(500000, 4, 25, extra: 10000000));
      expect(res.monthsToPayoff, 1);
      expect(res.schedule.single.balance, 0.0);
      expect(res.schedule.single.principal, closeTo(500000, 1e-6));
      expect(res.totalInterest, closeTo(500000 * 0.04 / 12, 0.01));
    });

    test('huge loans do not grow a phantom final row from float residue', () {
      for (final loan in [5e8, 1e9, 1e10]) {
        final res = calculateMortgage(_input(loan, 4, 25));
        expect(res.monthsToPayoff, 300, reason: 'loan $loan');
        expect(res.schedule.last.balance, 0.0);
      }
    });
  });
}
