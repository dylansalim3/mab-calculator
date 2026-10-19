import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/features/mab/mab_models.dart';
import 'package:moneykit/features/mab/mab_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final input = MabDraft(
    openingBalance: -12.5,
    openingDate: DateTime(2025, 4, 9),
    transactions: [
      MabTransaction(
        name: 'Food, lunch',
        date: DateTime(2025, 4, 30),
        amount: -3,
      ),
      MabTransaction(
        name: 'Transfer',
        date: DateTime(2025, 5, 1),
        amount: 150.25,
      ),
    ],
  );

  test('a blank balance and its transactions are stored too', () async {
    await MabStore().save(
      MabDraft(
        openingDate: DateTime(2025, 4, 9),
        transactions: [
          MabTransaction(name: 'A', date: DateTime(2025, 4, 10), amount: 5),
        ],
      ),
    );
    final loaded = (await MabStore().load())!;
    expect(loaded.openingBalance, isNull);
    expect(loaded.transactions.single.name, 'A');
  });

  test('load returns null when nothing is stored', () async {
    expect(await MabStore().load(), isNull);
  });

  test('save then load round-trips', () async {
    final store = MabStore();
    await store.save(input);
    final loaded = (await MabStore().load())!;
    expect(loaded.openingBalance, -12.5);
    expect(loaded.openingDate, DateTime(2025, 4, 9));
    expect(loaded.transactions.map((t) => t.name), ['Food, lunch', 'Transfer']);
    expect(loaded.transactions.map((t) => t.date), [
      DateTime(2025, 4, 30),
      DateTime(2025, 5, 1),
    ]);
    expect(loaded.transactions.map((t) => t.amount), [-3, 150.25]);
  });

  test('stored JSON uses the documented key and shape', () async {
    await MabStore().save(input);
    final raw = (await SharedPreferences.getInstance()).getString(
      'mab_state_v1',
    )!;
    final json = jsonDecode(raw) as Map<String, Object?>;
    expect(json['openingBalance'], -12.5);
    expect(json['openingDate'], '2025-04-09');
    expect((json['transactions']! as List).length, 2);
  });

  test('save overwrites and clear removes', () async {
    final store = MabStore();
    await store.save(input);
    await store.save(
      MabDraft(openingBalance: 1, openingDate: DateTime(2024, 2, 1)),
    );
    expect((await store.load())!.transactions, isEmpty);
    await store.clear();
    expect(await store.load(), isNull);
  });

  group('corrupt data loads as null', () {
    for (final entry in {
      'not json': 'not json{',
      'wrong top-level type': '[1, 2]',
      'missing fields': '{}',
      'bad date':
          '{"openingBalance": 1, "openingDate": "yesterday", "transactions": []}',
      'bad balance type':
          '{"openingBalance": "1", "openingDate": "2025-04-01", "transactions": []}',
      'bad transaction':
          '{"openingBalance": 1, "openingDate": "2025-04-01", "transactions": [{"name": 1}]}',
      'null transactions':
          '{"openingBalance": 1, "openingDate": "2025-04-01", "transactions": null}',
    }.entries) {
      test(entry.key, () async {
        SharedPreferences.setMockInitialValues({'mab_state_v1': entry.value});
        expect(await MabStore().load(), isNull);
      });
    }

    test('value of the wrong preference type', () async {
      SharedPreferences.setMockInitialValues({'mab_state_v1': 42});
      expect(await MabStore().load(), isNull);
    });
  });
}
