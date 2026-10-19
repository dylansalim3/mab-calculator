import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/features/split/split_engine.dart';
import 'package:moneykit/features/split/split_models.dart';

const _a = Person(id: 1, name: 'A');
const _b = Person(id: 2, name: 'B');
const _c = Person(id: 3, name: 'C');
const _d = Person(id: 4, name: 'D');

Payment _p(int id, double amount, int? payer) =>
    Payment(id: id, amount: amount, payerId: payer);

void main() {
  group('quick split', () {
    test('SPL-1 exact thirds', () {
      final r = calculateQuickSplit(bill: 100, pax: 3);
      expect(r.perPerson, 33.33);
      expect(r.totalBill, 100);
      expect(r.roundedTotal, closeTo(99.99, 1e-9));
    });
    test('SPL-2 6% SST over 4', () {
      final r = calculateQuickSplit(bill: 100, pax: 4, surcharge: 0.06);
      expect(r.surchargeAmount, closeTo(6, 1e-9));
      expect(r.totalBill, closeTo(106, 1e-9));
      expect(r.perPerson, 26.5);
    });
    test('SPL-3 rounding modes', () {
      expect(
        calculateQuickSplit(
          bill: 100,
          pax: 3,
          surcharge: 0.16,
          rounding: SplitRounding.round,
        ).perPerson,
        39,
      );
      expect(
        calculateQuickSplit(
          bill: 100,
          pax: 3,
          rounding: SplitRounding.ceil,
        ).perPerson,
        34,
      );
      final r = calculateQuickSplit(
        bill: 100,
        pax: 3,
        rounding: SplitRounding.round,
      );
      expect(r.perPerson, 33);
      expect(r.roundedTotal, 99);
    });
    test('pax below 1 is treated as 1; zero bill is zero', () {
      expect(calculateQuickSplit(bill: 50, pax: 0).pax, 1);
      expect(calculateQuickSplit(bill: 0, pax: 3).perPerson, 0);
    });
  });

  group('settlement', () {
    test('SPL-4 expenses + kitty contribution', () {
      final r = calculateSettlement(
        people: [_a, _b, _c],
        expenses: [_p(1, 90, 1), _p(2, 30, 2)],
        funds: [_p(3, 60, 3)],
      );
      expect(r.pool, 180);
      expect(r.fairShare, 60);
      expect(r.balances.map((m) => m.balance), [30, -30, 0]);
      expect(r.transfers.length, 1);
      expect(r.transfers.single.fromName, 'B');
      expect(r.transfers.single.toName, 'A');
      expect(r.transfers.single.amount, 30);
    });

    test('SPL-5 one payer, two debtors', () {
      final r = calculateSettlement(
        people: [_a, _b, _c],
        expenses: [_p(1, 100, 1)],
        funds: const [],
      );
      expect(r.fairShare, closeTo(33.3333, 1e-3));
      expect(r.transfers.map((t) => '${t.fromName}>${t.toName}:${t.amount}'), [
        'B>A:33.33',
        'C>A:33.33',
      ]);
    });

    test('SPL-6 unassigned and non-member payers are ignored', () {
      final r = calculateSettlement(
        people: [_a, _b],
        expenses: [_p(1, 50, 1), _p(2, 40, null), _p(3, 10, 99)],
        funds: const [],
      );
      expect(r.pool, 50);
      expect(r.transfers.single.amount, 25);
    });

    test('SPL-7 nobody, or nothing paid, gives no transfers', () {
      expect(
        calculateSettlement(
          people: const [],
          expenses: [_p(1, 5, 1)],
          funds: const [],
        ).transfers,
        isEmpty,
      );
      final r = calculateSettlement(
        people: [_a, _b],
        expenses: const [],
        funds: const [],
      );
      expect(r.transfers, isEmpty);
      expect(r.pool, 0);
    });

    test('SPL-8 greedy matching across several people', () {
      final r = calculateSettlement(
        people: [_a, _b, _c, _d],
        expenses: [_p(1, 120, 1), _p(2, 60, 2)],
        funds: const [],
      );
      expect(r.fairShare, 45);
      expect(r.transfers.map((t) => '${t.fromName}>${t.toName}:${t.amount}'), [
        'C>A:45.0',
        'D>A:30.0',
        'D>B:15.0',
      ]);
      // Everyone ends at zero.
      final net = {for (final m in r.balances) m.id: m.balance};
      for (final t in r.transfers) {
        net[t.fromId] = net[t.fromId]! + t.amount;
        net[t.toId] = net[t.toId]! - t.amount;
      }
      for (final v in net.values) {
        expect(v.abs(), lessThan(0.011));
      }
    });

    test('already even means no transfers', () {
      final r = calculateSettlement(
        people: [_a, _b],
        expenses: [_p(1, 20, 1), _p(2, 20, 2)],
        funds: const [],
      );
      expect(r.transfers, isEmpty);
      expect(r.pool, 40);
    });
  });
}
