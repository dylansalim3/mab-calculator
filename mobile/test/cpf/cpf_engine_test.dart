import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/features/cpf/cpf_engine.dart';
import 'package:moneykit/features/cpf/cpf_models.dart';

const _tol = 0.01;

Matcher _near(double v) => closeTo(v, _tol);

void main() {
  test('CPF-1: below 55, 1 year', () {
    final r = calculateCpf(
      const CpfInput(
        ageBand: CpfAgeBand.below55,
        oa: 20000,
        saOrRa: 10000,
        ma: 10000,
        years: 1,
      ),
    );
    expect(r.yearly, hasLength(1));
    expect(r.totalBasicInterest, _near(1300));
    expect(r.totalExtraInterest, _near(400));
    expect(r.totalInterest, _near(1700));
    expect(r.finalOa, _near(20500));
    expect(r.finalSaOrRa, _near(10800));
    expect(r.finalMa, _near(10400));
  });

  test('CPF-2: below 55, extra base capped at 60,000', () {
    final r = calculateCpf(
      const CpfInput(
        ageBand: CpfAgeBand.below55,
        oa: 50000,
        saOrRa: 50000,
        ma: 50000,
        years: 1,
      ),
    );
    expect(r.totalBasicInterest, _near(5250));
    expect(r.totalExtraInterest, _near(600));
    expect(r.totalInterest, _near(5850));
    expect(r.finalSaOrRa, _near(52600));
  });

  test('CPF-3: 55 and above, tiered extra interest', () {
    final r = calculateCpf(
      const CpfInput(
        ageBand: CpfAgeBand.from55,
        oa: 30000,
        saOrRa: 30000,
        ma: 10000,
        years: 1,
      ),
    );
    expect(r.totalBasicInterest, _near(2350));
    expect(r.totalExtraInterest, _near(900));
    expect(r.totalInterest, _near(3250));
    expect(r.finalOa, _near(30750));
    expect(r.finalSaOrRa, _near(32100));
    expect(r.finalMa, _near(10400));
  });

  test('CPF-4: monthly OA contributions use lowest (opening) balance', () {
    final r = calculateCpf(
      const CpfInput(ageBand: CpfAgeBand.below55, monthlyOa: 1000, years: 1),
    );
    expect(r.totalBasicInterest, _near(137.50));
    expect(r.totalExtraInterest, _near(55.00));
    expect(r.totalInterest, _near(192.50));
    expect(r.finalOa, _near(12137.50));
    expect(r.finalSaOrRa, _near(55.00));
    expect(r.finalMa, _near(0));
  });

  test('CPF-5: interest compounds yearly', () {
    final r = calculateCpf(
      const CpfInput(
        ageBand: CpfAgeBand.below55,
        oa: 20000,
        saOrRa: 10000,
        ma: 10000,
        years: 2,
      ),
    );
    expect(r.yearly, hasLength(2));
    expect(r.yearly[0].totalInterest, _near(1700));
    expect(r.yearly[1].totalInterest, greaterThan(r.yearly[0].totalInterest));
    expect(r.yearly[1].year, 2);
  });

  test('zero balances and contributions give all zeros', () {
    for (final band in CpfAgeBand.values) {
      final r = calculateCpf(CpfInput(ageBand: band, years: 3));
      expect(r.finalTotal, 0);
      expect(r.totalInterest, 0);
      expect(r.yearly.every((y) => y.totalEnd == 0), isTrue);
    }
  });

  test('custom OA rate changes OA interest', () {
    final r = calculateCpf(
      const CpfInput(
        ageBand: CpfAgeBand.below55,
        oa: 10000,
        oaRate: 3.5,
        years: 1,
      ),
    );
    expect(r.totalBasicInterest, _near(350));
    expect(r.totalExtraInterest, _near(100));
    expect(r.finalOa, _near(10350));
  });

  group('55+ tier boundaries (extra interest, RA only)', () {
    double extra(double ra) => calculateCpf(
      CpfInput(ageBand: CpfAgeBand.from55, saOrRa: ra, years: 1),
    ).totalExtraInterest;

    test('base 30,000 -> 2% on all', () => expect(extra(30000), _near(600)));
    test(
      'base 60,000 -> 2% on 30k + 1% on 30k',
      () => expect(extra(60000), _near(900)),
    );
    test(
      'base 90,000 -> capped at 60,000 base',
      () => expect(extra(90000), _near(900)),
    );
    test('base 15,000 -> 2% on all', () => expect(extra(15000), _near(300)));
  });

  test('below 55 extra base capped at 60,000', () {
    double extra(double sa) => calculateCpf(
      CpfInput(ageBand: CpfAgeBand.below55, saOrRa: sa, years: 1),
    ).totalExtraInterest;
    expect(extra(60000), _near(600));
    expect(extra(90000), _near(600));
  });

  test('OA above 20,000 is capped inside the extra base', () {
    double extra(double oa) => calculateCpf(
      CpfInput(ageBand: CpfAgeBand.below55, oa: oa, years: 1),
    ).totalExtraInterest;
    expect(extra(20000), _near(200));
    expect(extra(100000), _near(200));
    expect(extra(10000), _near(100));
  });

  test('years=40 returns 40 rows numbered 1..40', () {
    final r = calculateCpf(
      const CpfInput(
        ageBand: CpfAgeBand.below55,
        oa: 1000,
        monthlyOa: 100,
        years: 40,
      ),
    );
    expect(r.yearly, hasLength(40));
    expect(
      [for (final y in r.yearly) y.year],
      [for (var i = 1; i <= 40; i++) i],
    );
    expect(r.finalTotal, greaterThan(1000 + 100 * 480));
  });
}
