import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/features/interest/interest_engine.dart';
import 'package:moneykit/features/interest/interest_models.dart';

const _tol = 0.01;
Matcher _near(double v) => closeTo(v, _tol);

InterestInput _input({
  required double principal,
  required double rate,
  required int years,
  int months = 0,
  InterestType type = InterestType.compound,
  Compounding compounding = Compounding.monthly,
  double contribution = 0,
}) => InterestInput(
  principal: principal,
  annualRatePercent: rate,
  years: years,
  months: months,
  type: type,
  compounding: compounding,
  monthlyContribution: contribution,
);

void main() {
  group('golden vectors (PLAN.md §3.2)', () {
    test('INT-1: P 10 000, 5 %, 10 y, compound monthly, no contribution', () {
      final res = calculateInterest(
        _input(
          principal: 10000,
          rate: 5,
          years: 10,
          compounding: Compounding.monthly,
        ),
      );
      expect(res.finalBalance, _near(16470.09));
      expect(res.totalInterest, _near(6470.09));
      expect(res.totalContributions, 0.0);
    });

    test('INT-2: same as INT-1, compounding annually', () {
      final res = calculateInterest(
        _input(
          principal: 10000,
          rate: 5,
          years: 10,
          compounding: Compounding.annually,
        ),
      );
      expect(res.finalBalance, _near(16288.95));
      expect(res.totalInterest, _near(6288.95));
      expect(res.totalContributions, 0.0);
    });

    test('INT-3: same as INT-1, compounding daily', () {
      final res = calculateInterest(
        _input(
          principal: 10000,
          rate: 5,
          years: 10,
          compounding: Compounding.daily,
        ),
      );
      expect(res.finalBalance, _near(16486.65));
      expect(res.totalInterest, _near(6486.65));
      expect(res.totalContributions, 0.0);
    });

    test('INT-4: P 10 000, 5 %, 10 y, simple', () {
      final res = calculateInterest(
        _input(principal: 10000, rate: 5, years: 10, type: InterestType.simple),
      );
      expect(res.finalBalance, _near(15000.00));
      expect(res.totalInterest, _near(5000.00));
      expect(res.totalContributions, 0.0);
    });

    test('INT-5: P 10 000, 5 %, 10 y, compound monthly, +200/month', () {
      final res = calculateInterest(
        _input(
          principal: 10000,
          rate: 5,
          years: 10,
          compounding: Compounding.monthly,
          contribution: 200,
        ),
      );
      expect(res.finalBalance, _near(47526.55));
      expect(res.totalContributions, _near(24000.00));
      expect(res.totalInterest, _near(13526.55));
    });

    test('INT-6: P 5 000, 0 %, 2 y, +100/month, compound', () {
      final res = calculateInterest(
        _input(principal: 5000, rate: 0, years: 2, contribution: 100),
      );
      expect(res.finalBalance, _near(7400.00));
      expect(res.totalInterest, _near(0.0));
      expect(res.totalContributions, _near(2400.00));
    });

    test('INT-7: P 1 000, 12 %, 1 y 6 m, simple, +0', () {
      final res = calculateInterest(
        _input(
          principal: 1000,
          rate: 12,
          years: 1,
          months: 6,
          type: InterestType.simple,
        ),
      );
      expect(res.finalBalance, _near(1180.00));
      expect(res.totalInterest, _near(180.00));
      expect(res.totalContributions, 0.0);
    });
  });

  group('yearly rows and totals', () {
    test('yearly rows sum to totals and rows balance', () {
      for (final type in InterestType.values) {
        final res = calculateInterest(
          _input(
            principal: 12000,
            rate: 6.5,
            years: 3,
            months: 7,
            type: type,
            contribution: 150,
          ),
        );

        final sumInterest = res.yearly.fold(0.0, (a, r) => a + r.interest);
        final sumContrib = res.yearly.fold(0.0, (a, r) => a + r.contributions);

        expect(sumInterest, closeTo(res.totalInterest, 1e-6));
        expect(sumContrib, closeTo(res.totalContributions, 1e-6));

        for (final row in res.yearly) {
          expect(
            row.startBalance + row.contributions + row.interest,
            closeTo(row.endBalance, 1e-6),
          );
        }

        for (var i = 1; i < res.yearly.length; i++) {
          expect(res.yearly[i].startBalance, res.yearly[i - 1].endBalance);
        }
        expect(res.yearly.first.startBalance, 12000);
        expect(res.yearly.last.endBalance, res.finalBalance);
      }
    });

    test(
      'partial year: 1 year 6 months gives 2 rows, second has months == 6',
      () {
        final res = calculateInterest(
          _input(principal: 1000, rate: 5, years: 1, months: 6),
        );
        expect(res.yearly, hasLength(2));
        expect(res.yearly[0].year, 1);
        expect(res.yearly[0].months, 12);
        expect(res.yearly[1].year, 2);
        expect(res.yearly[1].months, 6);
      },
    );

    test('partial year: 0 years 5 months gives 1 row with months == 5', () {
      final res = calculateInterest(
        _input(principal: 2000, rate: 4, years: 0, months: 5),
      );
      expect(res.yearly, hasLength(1));
      expect(res.yearly[0].year, 1);
      expect(res.yearly[0].months, 5);
      expect(res.yearly[0].startBalance, 2000);
    });

    test('exact years gives rows with months == 12 each', () {
      final res = calculateInterest(
        _input(principal: 10000, rate: 3, years: 4),
      );
      expect(res.yearly, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(res.yearly[i].year, i + 1);
        expect(res.yearly[i].months, 12);
      }
    });
  });

  group('monthlyBalances', () {
    test(
      'length is totalMonths + 1, starts with principal, ends with finalBalance',
      () {
        final input = _input(
          principal: 5000,
          rate: 4,
          years: 2,
          months: 3,
          contribution: 50,
        );
        final res = calculateInterest(input);
        expect(res.monthlyBalances, hasLength(input.totalMonths + 1));
        expect(res.monthlyBalances.first, 5000);
        expect(res.monthlyBalances.last, res.finalBalance);
      },
    );

    test(
      'monotonic non-decreasing for positive rates and non-negative contributions',
      () {
        for (final type in InterestType.values) {
          final res = calculateInterest(
            _input(
              principal: 1000,
              rate: 5,
              years: 2,
              type: type,
              contribution: 100,
            ),
          );
          for (var i = 1; i < res.monthlyBalances.length; i++) {
            expect(
              res.monthlyBalances[i],
              greaterThanOrEqualTo(res.monthlyBalances[i - 1]),
            );
          }
        }
      },
    );
  });

  group('simple vs compound ordering', () {
    test('compound >= simple for identical inputs', () {
      for (final years in [1, 5, 10]) {
        for (final contrib in [0.0, 150.0]) {
          final compoundRes = calculateInterest(
            _input(
              principal: 10000,
              rate: 6,
              years: years,
              type: InterestType.compound,
              compounding: Compounding.monthly,
              contribution: contrib,
            ),
          );
          final simpleRes = calculateInterest(
            _input(
              principal: 10000,
              rate: 6,
              years: years,
              type: InterestType.simple,
              contribution: contrib,
            ),
          );
          expect(
            compoundRes.finalBalance,
            greaterThanOrEqualTo(simpleRes.finalBalance),
          );
          expect(
            compoundRes.totalInterest,
            greaterThanOrEqualTo(simpleRes.totalInterest),
          );
        }
      }
    });

    test('higher compounding frequency yields higher final balance', () {
      final annual = calculateInterest(
        _input(
          principal: 10000,
          rate: 7,
          years: 5,
          compounding: Compounding.annually,
        ),
      );
      final semi = calculateInterest(
        _input(
          principal: 10000,
          rate: 7,
          years: 5,
          compounding: Compounding.semiAnnually,
        ),
      );
      final quarterly = calculateInterest(
        _input(
          principal: 10000,
          rate: 7,
          years: 5,
          compounding: Compounding.quarterly,
        ),
      );
      final monthly = calculateInterest(
        _input(
          principal: 10000,
          rate: 7,
          years: 5,
          compounding: Compounding.monthly,
        ),
      );
      final daily = calculateInterest(
        _input(
          principal: 10000,
          rate: 7,
          years: 5,
          compounding: Compounding.daily,
        ),
      );

      expect(daily.finalBalance, greaterThan(monthly.finalBalance));
      expect(monthly.finalBalance, greaterThan(quarterly.finalBalance));
      expect(quarterly.finalBalance, greaterThan(semi.finalBalance));
      expect(semi.finalBalance, greaterThan(annual.finalBalance));
    });
  });

  group('zero and edge cases', () {
    test(
      'rate 0 with 0 contribution gives 0 interest and preserves principal',
      () {
        final res = calculateInterest(
          _input(principal: 8000, rate: 0, years: 3),
        );
        expect(res.finalBalance, 8000);
        expect(res.totalInterest, 0);
        expect(res.totalContributions, 0);
        expect(res.yearly.every((y) => y.interest == 0), isTrue);
      },
    );

    test('principal 0 earns interest only on contributions after deposit', () {
      final res = calculateInterest(
        _input(
          principal: 0,
          rate: 5,
          years: 1,
          compounding: Compounding.monthly,
          contribution: 500,
        ),
      );
      expect(res.totalContributions, 6000);
      // In month 1: principal is 0, so month 1 earns 0 interest, ending at 500.
      expect(res.monthlyBalances[0], 0);
      expect(res.monthlyBalances[1], 500);
      expect(res.totalInterest, greaterThan(0));
      expect(
        res.finalBalance,
        closeTo(res.totalContributions + res.totalInterest, 1e-6),
      );
    });

    test('principal 0 and rate 0 returns contributions only', () {
      final res = calculateInterest(
        _input(principal: 0, rate: 0, years: 2, contribution: 200),
      );
      expect(res.finalBalance, 4800);
      expect(res.totalContributions, 4800);
      expect(res.totalInterest, 0);
    });

    test('totalMonths <= 0 returns initial state', () {
      final res = calculateInterest(
        _input(principal: 1500, rate: 5, years: 0, months: 0),
      );
      expect(res.finalBalance, 1500);
      expect(res.totalContributions, 0);
      expect(res.totalInterest, 0);
      expect(res.yearly, isEmpty);
      expect(res.monthlyBalances, [1500]);
    });

    test('1 month term produces single row with months == 1', () {
      final res = calculateInterest(
        _input(principal: 1200, rate: 10, years: 0, months: 1),
      );
      expect(res.yearly, hasLength(1));
      expect(res.yearly.single.months, 1);
      expect(res.monthlyBalances, hasLength(2));
    });
  });
}
