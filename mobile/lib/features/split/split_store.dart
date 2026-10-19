import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'split_models.dart';

/// Everything on the trip-settlement side of the Split tab.
class SplitState {
  const SplitState({
    this.people = const [],
    this.expenses = const [],
    this.funds = const [],
    this.nextId = 1,
  });

  final List<Person> people;
  final List<Payment> expenses;
  final List<Payment> funds;
  final int nextId;
}

/// Persists [SplitState] as JSON until the user clears it. Never throws:
/// corrupt data → null.
class SplitStore {
  static const _key = 'split_state_v1';

  Future<SplitState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, Object?>;
      List<T> list<T>(String k, T Function(Map<String, Object?>) f) => [
        for (final e in j[k]! as List<Object?>) f(e! as Map<String, Object?>),
      ];
      return SplitState(
        people: list('people', Person.fromJson),
        expenses: list('expenses', Payment.fromJson),
        funds: list('funds', Payment.fromJson),
        nextId: (j['nextId']! as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SplitState s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'people': [for (final p in s.people) p.toJson()],
          'expenses': [for (final p in s.expenses) p.toJson()],
          'funds': [for (final p in s.funds) p.toJson()],
          'nextId': s.nextId,
        }),
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
