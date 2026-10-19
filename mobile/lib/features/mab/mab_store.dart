import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/parse.dart';
import 'mab_models.dart';

/// What the MAB screen holds. Unlike [MabInput] the balance may be blank, so
/// work in progress survives restarts.
class MabDraft {
  const MabDraft({
    this.openingBalance,
    required this.openingDate,
    this.transactions = const [],
  });

  final double? openingBalance;
  final DateTime openingDate;
  final List<MabTransaction> transactions;
}

/// Persists the last MAB session (opening balance, opening date, transactions)
/// in `shared_preferences` as JSON until the user clears it. Never throws:
/// corrupt data → null.
class MabStore {
  static const _key = 'mab_state_v1';

  Future<MabDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, Object?>;
      final date = DateTime.parse(json['openingDate']! as String);
      final balance = (json['openingBalance'] as num?)?.toDouble();
      if (balance != null && !balance.isFinite) return null;
      return MabDraft(
        openingBalance: balance,
        openingDate: dateOnly(date),
        transactions: [
          for (final t in json['transactions']! as List<Object?>)
            MabTransaction.fromJson(t! as Map<String, Object?>),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(MabDraft input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = input.openingDate;
      await prefs.setString(
        _key,
        jsonEncode({
          'openingBalance': input.openingBalance,
          'openingDate':
              '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}',
          'transactions': [for (final t in input.transactions) t.toJson()],
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
