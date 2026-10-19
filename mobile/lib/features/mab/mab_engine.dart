import 'mab_models.dart';

/// Computes the Monthly Average Balance. Spec: docs/PLAN.md §3.1.
MabResult calculateMab(MabInput input) {
  final open = input.openingDate;
  final cycleStart = DateTime(open.year, open.month, 1);
  final cycleEnd = DateTime(open.year, open.month + 1, 0);
  final days = cycleEnd.day;

  final deltas = List<double>.filled(days, 0);
  final ignored = <MabTransaction>[];
  var counted = 0;
  for (final t in input.transactions) {
    if (t.date.year == open.year && t.date.month == open.month) {
      deltas[t.date.day - 1] += t.amount;
      counted++;
    } else {
      ignored.add(t);
    }
  }

  final daily = <DailyBalance>[];
  var balance = input.openingBalance;
  var sum = 0.0;
  var minBalance = double.infinity;
  var maxBalance = double.negativeInfinity;
  for (var i = 0; i < days; i++) {
    balance += deltas[i];
    daily.add(DailyBalance(DateTime(open.year, open.month, i + 1), balance));
    sum += balance;
    if (balance < minBalance) minBalance = balance;
    if (balance > maxBalance) maxBalance = balance;
  }

  return MabResult(
    cycleStart: cycleStart,
    cycleEnd: cycleEnd,
    daily: daily,
    mab: sum / days,
    minBalance: minBalance,
    maxBalance: maxBalance,
    ignored: ignored,
    countedTransactions: counted,
  );
}
