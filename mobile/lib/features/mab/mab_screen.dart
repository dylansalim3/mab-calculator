import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/parse.dart';
import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import 'mab_csv.dart';
import 'mab_engine.dart';
import 'mab_models.dart';
import 'mab_store.dart';

const _amountError = 'Enter a valid amount';

const _csvSample =
    'Account,Date,Balance\n'
    '"Start Amount","1 April, 2025",500.00\n'
    '"Transfer","30 April, 2025",150.00';

/// `500`, `100.5`: how a stored amount is written back into a text field.
String _inputText(double v) =>
    v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

class MabScreen extends StatefulWidget {
  const MabScreen({super.key, MabStore? store}) : _store = store;

  final MabStore? _store;
  MabStore get store => _store ?? MabStore();

  @override
  State<MabScreen> createState() => _MabScreenState();
}

class _MabScreenState extends State<MabScreen> {
  late final MabStore _store = widget.store;
  final _balance = TextEditingController();
  var _balanceTouched = false;
  var _edited = false;
  var _openingDate = dateOnly(DateTime.now());
  var _transactions = <MabTransaction>[];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _balance.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    MabDraft? saved;
    try {
      saved = await _store.load();
    } catch (_) {}
    final restored = saved;
    if (!mounted || _edited || restored == null) return;
    setState(() => _apply(restored));
  }

  void _apply(MabDraft input) {
    final balance = input.openingBalance;
    _balance.text = balance == null ? '' : _inputText(balance);
    _balanceTouched = false;
    _openingDate = input.openingDate;
    _transactions = List.of(input.transactions);
  }

  /// Applies a change, then saves it without blocking the UI. Everything is
  /// kept on the device until the user taps Reset.
  void _update(VoidCallback change) {
    setState(() {
      _edited = true;
      change();
    });
    unawaited(
      _store.save(
        MabDraft(
          openingBalance: parseNum(_balance.text),
          openingDate: _openingDate,
          transactions: _transactions,
        ),
      ),
    );
  }

  Future<void> _openSheet({int? index}) async {
    final result = await showModalBottomSheet<MabTransaction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransactionSheet(
        cycleMonth: _openingDate,
        initial: index == null ? null : _transactions[index],
      ),
    );
    if (result == null || !mounted) return;
    _update(() {
      if (index == null) {
        _transactions = [..._transactions, result];
      } else {
        _transactions = List.of(_transactions)..[index] = result;
      }
    });
  }

  Future<void> _import() async {
    final input = await showDialog<MabInput>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (input == null || !mounted) return;
    _update(
      () => _apply(
        MabDraft(
          openingBalance: input.openingBalance,
          openingDate: input.openingDate,
          transactions: input.transactions,
        ),
      ),
    );
    final n = input.transactions.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $n transaction${n == 1 ? '' : 's'}')),
    );
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This removes the opening balance and all transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _edited = true;
      _balance.clear();
      _balanceTouched = false;
      _openingDate = dateOnly(DateTime.now());
      _transactions = [];
    });
    unawaited(_store.clear());
  }

  @override
  Widget build(BuildContext context) {
    final balance = parseNum(_balance.text);
    final cycleStart = DateTime(_openingDate.year, _openingDate.month, 1);
    final cycleEnd = DateTime(_openingDate.year, _openingDate.month + 1, 0);
    final balanceError = _balanceTouched && balance == null
        ? _amountError
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MAB Calculator'),
        actions: [
          IconButton(
            tooltip: 'Import CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _import,
          ),
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: ScreenBody(
        children: [
          SectionCard(
            title: 'Opening balance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NumberField(
                  label: 'Opening balance',
                  controller: _balance,
                  prefixText: Fmt.currencySymbol,
                  allowNegative: true,
                  errorText: balanceError,
                  onChanged: (_) => _update(() => _balanceTouched = true),
                ),
                const SizedBox(height: 12),
                DateField(
                  label: 'Opening date',
                  value: _openingDate,
                  onChanged: (d) => _update(() => _openingDate = d),
                ),
                const SizedBox(height: 12),
                Text(
                  'Billing cycle: ${Fmt.date(cycleStart)} – ${Fmt.date(cycleEnd)} '
                  '(${cycleEnd.day} days)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          _transactionsCard(),
          ..._results(balance),
        ],
      ),
    );
  }

  Widget _transactionsCard() {
    final theme = Theme.of(context);
    final order = List<int>.generate(_transactions.length, (i) => i)
      ..sort((a, b) {
        final c = _transactions[a].date.compareTo(_transactions[b].date);
        return c != 0 ? c : a.compareTo(b);
      });
    final addButton = FilledButton.tonal(
      onPressed: _openSheet,
      child: const Text('Add transaction'),
    );
    // The header has no room for the button once text is scaled up.
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 18;
    return SectionCard(
      title: 'Transactions',
      trailing: largeText ? null : addButton,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (largeText) ...[addButton, const SizedBox(height: 8)],
          if (_transactions.isEmpty)
            Text(
              'No transactions yet. Add deposits and withdrawals made during the month.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            _tableHeader(),
            for (final i in order) _transactionRow(i),
          ],
        ],
      ),
    );
  }

  static const _dateFlex = 28;
  static const _nameFlex = 30;
  static const _amountFlex = 30;
  static const _actionWidth = 48.0;

  Widget _tableHeader() {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: _dateFlex,
            child: Text('Date', style: style),
          ),
          Expanded(
            flex: _nameFlex,
            child: Text('Name', style: style),
          ),
          Expanded(
            flex: _amountFlex,
            child: Text('Amount', style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: _actionWidth),
        ],
      ),
    );
  }

  Widget _transactionRow(int index) {
    final t = _transactions[index];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: () => _openSheet(index: index),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: _dateFlex,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Fmt.date(t.date),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            Expanded(
              flex: _nameFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  t.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            Expanded(
              flex: _amountFlex,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  Fmt.signedMoney(t.amount),
                  style: tabular(
                    theme.textTheme.bodyMedium?.copyWith(
                      color: t.amount >= 0 ? scheme.primary : scheme.error,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _actionWidth,
              child: IconButton(
                tooltip: 'Delete transaction',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _update(
                  () => _transactions = List.of(_transactions)..removeAt(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(double? balance) {
    if (balance == null) {
      return [
        _balanceTouched
            ? const EmptyState(
                icon: Icons.error_outline,
                message: 'Fix the highlighted fields to see results.',
              )
            : const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message:
                    'Enter an opening balance to see your Monthly Average Balance.',
              ),
      ];
    }

    final r = calculateMab(
      MabInput(
        openingBalance: balance,
        openingDate: _openingDate,
        transactions: _transactions,
      ),
    );
    final scheme = Theme.of(context).colorScheme;
    return [
      ResultHero(label: 'Monthly Average Balance', value: Fmt.money(r.mab)),
      if (r.ignored.isNotEmpty)
        InlineBanner(message: _ignoredMessage(r.ignored)),
      SectionCard(
        title: 'Summary',
        child: Column(
          children: [
            StatRow(
              label: 'Lowest daily balance',
              value: Fmt.money(r.minBalance),
            ),
            StatRow(
              label: 'Highest daily balance',
              value: Fmt.money(r.maxBalance),
            ),
            StatRow(label: 'Days in cycle', value: '${r.days}'),
            StatRow(
              label: 'Transactions counted',
              value: '${r.countedTransactions}',
            ),
          ],
        ),
      ),
      SectionCard(
        title: 'Daily balance',
        child: SimpleLineChart(
          values: [for (final d in r.daily) d.balance],
          stepped: true,
          xLabel: (i) => '${i + 1}',
        ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text('Daily balances (${r.days} days)'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final d in r.daily)
              StatRow(
                label: Fmt.date(d.date),
                value: Fmt.money(d.balance),
                valueColor: d.balance < 0 ? scheme.error : null,
              ),
          ],
        ),
      ),
    ];
  }

  String _ignoredMessage(List<MabTransaction> ignored) {
    final n = ignored.length;
    final list = ignored
        .map((t) => '${t.name} (${Fmt.date(t.date)})')
        .join(', ');
    return n == 1
        ? '1 transaction is outside the billing cycle and was ignored: $list'
        : '$n transactions are outside the billing cycle and were ignored: $list';
  }
}

class _TransactionSheet extends StatefulWidget {
  const _TransactionSheet({required this.cycleMonth, this.initial});

  final DateTime cycleMonth;
  final MabTransaction? initial;

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : _inputText(widget.initial!.amount.abs()),
  );
  late var _deposit = (widget.initial?.amount ?? 1) >= 0;
  late var _date = widget.initial?.date ?? widget.cycleMonth;
  var _amountTouched = false;
  var _dateTouched = false;
  var _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _amountValue {
    final v = parseNum(_amount.text);
    return v != null && v > 0 ? v : null;
  }

  bool get _dateValid => _sameMonth(_date, widget.cycleMonth);

  void _save() {
    setState(() => _submitted = true);
    final amount = _amountValue;
    if (amount == null || !_dateValid) return;
    final name = _name.text.trim();
    Navigator.pop(
      context,
      MabTransaction(
        name: name.isEmpty ? 'Transaction' : name,
        date: _date,
        amount: _deposit ? amount : -amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAmountError = _amountTouched || _submitted;
    final showDateError = _dateTouched || _submitted;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'Add transaction' : 'Edit transaction',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Deposit')),
                ButtonSegment(value: false, label: Text('Withdrawal')),
              ],
              selected: {_deposit},
              onSelectionChanged: (s) => setState(() => _deposit = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'Date',
              value: _date,
              errorText: showDateError && !_dateValid
                  ? 'Date must be within the billing cycle'
                  : null,
              onChanged: (d) => setState(() {
                _date = d;
                _dateTouched = true;
              }),
            ),
            const SizedBox(height: 12),
            NumberField(
              label: 'Amount',
              controller: _amount,
              prefixText: Fmt.currencySymbol,
              textInputAction: TextInputAction.done,
              errorText: showAmountError && _amountValue == null
                  ? _amountError
                  : null,
              onChanged: (_) => setState(() => _amountTouched = true),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();
  var _errors = const <String>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Nothing is imported unless every row parses, so data is never silently dropped.
  void _submit() {
    final result = parseMabCsv(_text.text);
    final input = result.input;
    if (input != null && result.errors.isEmpty) {
      Navigator.pop(context, input);
      return;
    }
    setState(
      () => _errors = result.errors.isEmpty ? ['No data found'] : result.errors,
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return AlertDialog(
      title: const Text('Import from CSV'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Paste CSV',
              alignLabelWithHint: true,
              helperText: _csvSample,
              helperMaxLines: 4,
            ),
          ),
          for (final e in _errors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e, style: errorStyle),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Import')),
      ],
    );
  }
}
