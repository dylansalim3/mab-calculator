import 'package:intl/intl.dart';

/// Display formatting. All user-visible numbers/dates go through here.
class Fmt {
  Fmt._();

  static const currencySymbol = '\$';

  static final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _int = NumberFormat('#,##0', 'en_US');
  static final DateFormat _date = DateFormat('d MMM yyyy', 'en_US');
  static final DateFormat _monthYear = DateFormat('MMM yyyy', 'en_US');

  /// `$1,234.56`, negatives `-$1,234.56`. Avoids "-$0.00" and never throws.
  static String money(double v) {
    if (!v.isFinite) return '—';
    // round() and NumberFormat both saturate near int64; show huge values honestly.
    if (v.abs() >= 1e15) {
      return '${v < 0 ? '-' : ''}$currencySymbol${v.abs().toStringAsExponential(2)}';
    }
    final rounded = (v * 100).round() / 100;
    final s = '$currencySymbol${_money.format(rounded.abs())}';
    return rounded < 0 ? '-$s' : s;
  }

  /// `+$150.00` / `-$3.00`.
  static String signedMoney(double v) => v >= 0 ? '+${money(v)}' : money(v);

  static String integer(num v) => _int.format(v);

  static String percent(double v, {int dp = 2}) => '${v.toStringAsFixed(dp)}%';

  /// `1 Apr 2025`
  static String date(DateTime d) => _date.format(d);

  /// `Apr 2025`
  static String monthYear(DateTime d) => _monthYear.format(d);

  /// `25 yrs 0 mo`, `1 yr 6 mo`, `8 mo`.
  static String duration(int months) {
    final y = months ~/ 12;
    final m = months % 12;
    if (y == 0) return '$m mo';
    return '$y ${y == 1 ? 'yr' : 'yrs'} $m mo';
  }
}
