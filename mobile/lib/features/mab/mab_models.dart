/// MAB data types. Dates are date-only (`DateTime(y, m, d)`, local).
library;

class MabTransaction {
  const MabTransaction({
    required this.name,
    required this.date,
    required this.amount,
  });

  final String name;
  final DateTime date;

  /// Signed: deposits positive, withdrawals negative.
  final double amount;

  Map<String, Object?> toJson() => {
    'name': name,
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'amount': amount,
  };

  static MabTransaction fromJson(Map<String, Object?> j) {
    final d = DateTime.parse(j['date']! as String);
    return MabTransaction(
      name: j['name']! as String,
      date: DateTime(d.year, d.month, d.day),
      amount: (j['amount']! as num).toDouble(),
    );
  }
}

class MabInput {
  const MabInput({
    required this.openingBalance,
    required this.openingDate,
    this.transactions = const [],
  });

  final double openingBalance;
  final DateTime openingDate;
  final List<MabTransaction> transactions;
}

class DailyBalance {
  const DailyBalance(this.date, this.balance);
  final DateTime date;
  final double balance;
}

class MabResult {
  const MabResult({
    required this.cycleStart,
    required this.cycleEnd,
    required this.daily,
    required this.mab,
    required this.minBalance,
    required this.maxBalance,
    required this.ignored,
    required this.countedTransactions,
  });

  final DateTime cycleStart;
  final DateTime cycleEnd;

  /// One entry per day of the cycle, ascending.
  final List<DailyBalance> daily;

  /// Monthly Average Balance = sum(daily balance) / days.
  final double mab;
  final double minBalance;
  final double maxBalance;

  /// Transactions dated outside the cycle month (excluded from the maths).
  final List<MabTransaction> ignored;
  final int countedTransactions;

  int get days => daily.length;
}

/// Result of parsing pasted CSV text.
class MabCsvResult {
  const MabCsvResult({this.input, this.errors = const []});

  /// Null when the opening-balance row could not be parsed.
  final MabInput? input;

  /// Human-readable, e.g. `Row 4: invalid date 'abc'`. Row numbers are 1-based
  /// line numbers of the pasted text (header = row 1).
  final List<String> errors;
}
