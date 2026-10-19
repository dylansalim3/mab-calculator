import 'split_models.dart';

/// Even split of one bill, optionally with tax/service charge and rounding.
/// [surcharge] is a fraction (0.06 = 6 %). Spec: docs/PLAN.md §3.5.
QuickSplitResult calculateQuickSplit({
  required double bill,
  required int pax,
  double surcharge = 0,
  SplitRounding rounding = SplitRounding.exact,
}) {
  final people = pax < 1 ? 1 : pax;
  final surchargeAmount = bill * surcharge;
  final total = bill + surchargeAmount;
  final raw = total / people;
  final perPerson = switch (rounding) {
    SplitRounding.round => raw.roundToDouble(),
    SplitRounding.ceil => raw.ceilToDouble(),
    SplitRounding.exact => (raw * 100).round() / 100,
  };
  return QuickSplitResult(
    baseBill: bill,
    surchargeAmount: surchargeAmount,
    totalBill: total,
    pax: people,
    perPerson: perPerson,
    roundedTotal: perPerson * people,
  );
}

/// Who owes whom after a trip. Everyone's fair share is an equal part of the
/// pool (all expenses + kitty contributions attributed to a member). Payments
/// with no payer, or a payer who is not a member, are ignored. Transfers are
/// settled greedily, biggest debtor to biggest creditor. Spec: PLAN §3.5.
SettlementResult calculateSettlement({
  required List<Person> people,
  required List<Payment> expenses,
  required List<Payment> funds,
}) {
  if (people.isEmpty) {
    return const SettlementResult(
      balances: [],
      pool: 0,
      fairShare: 0,
      transfers: [],
    );
  }
  final paid = {for (final p in people) p.id: 0.0};
  for (final p in [...expenses, ...funds]) {
    final id = p.payerId;
    if (id != null && paid.containsKey(id)) paid[id] = paid[id]! + p.amount;
  }
  final pool = paid.values.fold(0.0, (a, b) => a + b);
  final fair = pool / people.length;
  final balances = [
    for (final p in people)
      MemberBalance(
        id: p.id,
        name: p.name,
        paid: paid[p.id]!,
        balance: paid[p.id]! - fair,
      ),
  ];
  return SettlementResult(
    balances: balances,
    pool: pool,
    fairShare: fair,
    transfers: pool <= 0 ? const [] : _transfers(balances),
  );
}

class _Side {
  _Side(this.id, this.name, this.amount, this.order);
  final int id;
  final String name;
  double amount;
  final int order;
}

List<Transfer> _transfers(List<MemberBalance> balances) {
  final creditors = <_Side>[];
  final debtors = <_Side>[];
  for (var i = 0; i < balances.length; i++) {
    final m = balances[i];
    final rounded = (m.balance * 100).round() / 100;
    if (rounded > 0.01) {
      creditors.add(_Side(m.id, m.name, rounded, i));
    } else if (rounded < -0.01) {
      debtors.add(_Side(m.id, m.name, -rounded, i));
    }
  }
  // Dart's sort is not stable: tie-break on member order.
  int bigFirst(_Side a, _Side b) {
    final c = b.amount.compareTo(a.amount);
    return c != 0 ? c : a.order.compareTo(b.order);
  }

  creditors.sort(bigFirst);
  debtors.sort(bigFirst);

  final out = <Transfer>[];
  var i = 0;
  var j = 0;
  while (i < debtors.length && j < creditors.length) {
    final d = debtors[i];
    final c = creditors[j];
    final amount = d.amount < c.amount ? d.amount : c.amount;
    if (amount > 0.01) {
      out.add(
        Transfer(
          fromId: d.id,
          fromName: d.name,
          toId: c.id,
          toName: c.name,
          amount: (amount * 100).round() / 100,
        ),
      );
    }
    d.amount -= amount;
    c.amount -= amount;
    if (d.amount < 0.01) i++;
    if (c.amount < 0.01) j++;
  }
  return out;
}
