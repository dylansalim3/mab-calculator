class Person {
  const Person({required this.id, required this.name});

  final int id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  static Person fromJson(Map<String, Object?> j) =>
      Person(id: (j['id']! as num).toInt(), name: j['name']! as String);
}

/// A payment made on the trip: a shared expense or a contribution to the kitty.
/// [payerId] null means unassigned (paid from the pool / nobody in particular).
class Payment {
  const Payment({
    required this.id,
    required this.amount,
    this.payerId,
    this.note = '',
  });

  final int id;
  final double amount;
  final int? payerId;
  final String note;

  Payment copyWith({
    double? amount,
    int? payerId,
    bool clearPayer = false,
    String? note,
  }) => Payment(
    id: id,
    amount: amount ?? this.amount,
    payerId: clearPayer ? null : (payerId ?? this.payerId),
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'payerId': payerId,
    'note': note,
  };

  static Payment fromJson(Map<String, Object?> j) => Payment(
    id: (j['id']! as num).toInt(),
    amount: (j['amount']! as num).toDouble(),
    payerId: (j['payerId'] as num?)?.toInt(),
    note: (j['note'] as String?) ?? '',
  );
}

class MemberBalance {
  const MemberBalance({
    required this.id,
    required this.name,
    required this.paid,
    required this.balance,
  });

  final int id;
  final String name;

  /// Expenses plus kitty contributions attributed to this person.
  final double paid;

  /// `paid - fairShare`: positive = gets back, negative = owes.
  final double balance;
}

class Transfer {
  const Transfer({
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
  });

  final int fromId;
  final String fromName;
  final int toId;
  final String toName;
  final double amount;

  String get key => '$fromId->$toId';
}

class SettlementResult {
  const SettlementResult({
    required this.balances,
    required this.pool,
    required this.fairShare,
    required this.transfers,
  });

  final List<MemberBalance> balances;

  /// Sum of everything paid by members.
  final double pool;
  final double fairShare;
  final List<Transfer> transfers;
}

enum SplitRounding { exact, round, ceil }

class QuickSplitResult {
  const QuickSplitResult({
    required this.baseBill,
    required this.surchargeAmount,
    required this.totalBill,
    required this.pax,
    required this.perPerson,
    required this.roundedTotal,
  });

  final double baseBill;
  final double surchargeAmount;
  final double totalBill;
  final int pax;
  final double perPerson;

  /// `perPerson * pax` — differs from [totalBill] when rounding is on.
  final double roundedTotal;
}
