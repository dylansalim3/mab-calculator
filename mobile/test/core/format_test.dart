import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/core/format.dart';
import 'package:moneykit/core/parse.dart';

void main() {
  test('money formatting', () {
    expect(Fmt.money(504.9), '\$504.90');
    expect(Fmt.money(1234567.891), '\$1,234,567.89');
    expect(Fmt.money(-3), '-\$3.00');
    expect(Fmt.money(-0.001), '\$0.00');
    expect(Fmt.money(1e20), '\$1.00e+20');
    expect(Fmt.money(-5e53), '-\$5.00e+53');
    expect(Fmt.money(double.infinity), '—');
    expect(Fmt.money(double.nan), '—');
    expect(Fmt.signedMoney(150), '+\$150.00');
    expect(Fmt.signedMoney(-3), '-\$3.00');
  });

  test('date + duration formatting', () {
    expect(Fmt.date(DateTime(2025, 4, 1)), '1 Apr 2025');
    expect(Fmt.monthYear(DateTime(2025, 4, 1)), 'Apr 2025');
    expect(Fmt.duration(300), '25 yrs 0 mo');
    expect(Fmt.duration(18), '1 yr 6 mo');
    expect(Fmt.duration(8), '8 mo');
  });

  test('parseNum', () {
    expect(parseNum('1,000.50'), 1000.5);
    expect(parseNum(' 12 '), 12);
    expect(parseNum(''), isNull);
    expect(parseNum('abc'), isNull);
    expect(parseNum('-5'), -5);
  });
}
