import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/parse.dart';
import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import 'split_engine.dart';
import 'split_models.dart';
import 'split_store.dart';

enum _Mode { settlement, quick }

const _surcharges = [
  ('None (0%)', 0.0),
  ('6% SST', 0.06),
  ('10% Service', 0.10),
  ('16% Combined', 0.16),
];

const _roundings = [
  ('Exact (cents)', SplitRounding.exact),
  ('Round to \$1', SplitRounding.round),
  ('Round up (\$1)', SplitRounding.ceil),
];

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key, SplitStore? store}) : _store = store;

  final SplitStore? _store;
  SplitStore get store => _store ?? SplitStore();

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  late final SplitStore _store = widget.store;
  var _mode = _Mode.settlement;
  var _state = const SplitState();
  var _edited = false;
  final _settled = <String>{};

  final _newPerson = TextEditingController();

  final _bill = TextEditingController();
  var _billTouched = false;
  var _pax = 3;
  var _surcharge = 0.0;
  var _rounding = SplitRounding.exact;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _newPerson.dispose();
    _bill.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    SplitState? saved;
    try {
      saved = await _store.load();
    } catch (_) {}
    final restored = saved;
    if (!mounted || _edited || restored == null) return;
    setState(() => _state = restored);
  }

  /// Applies a change and saves everything on the device without blocking.
  void _update(SplitState Function(SplitState s) change) {
    setState(() {
      _edited = true;
      _state = change(_state);
    });
    unawaited(_store.save(_state));
  }

  SplitState _with(
    SplitState s, {
    List<Person>? people,
    List<Payment>? expenses,
    List<Payment>? funds,
    int? nextId,
  }) => SplitState(
    people: people ?? s.people,
    expenses: expenses ?? s.expenses,
    funds: funds ?? s.funds,
    nextId: nextId ?? s.nextId,
  );

  void _addPerson() {
    final name = _newPerson.text.trim();
    if (name.isEmpty) return;
    _newPerson.clear();
    _update(
      (s) => _with(
        s,
        people: [
          ...s.people,
          Person(id: s.nextId, name: name),
        ],
        nextId: s.nextId + 1,
      ),
    );
  }

  void _removePerson(Person p) {
    // Their payments stay on the list but become unassigned.
    Payment detach(Payment x) =>
        x.payerId == p.id ? x.copyWith(clearPayer: true) : x;
    _update(
      (s) => _with(
        s,
        people: [...s.people.where((x) => x.id != p.id)],
        expenses: [for (final e in s.expenses) detach(e)],
        funds: [for (final f in s.funds) detach(f)],
      ),
    );
  }

  Future<void> _editPayment({required bool kitty, Payment? initial}) async {
    final result = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PaymentSheet(
        title: initial == null
            ? (kitty ? 'Add contribution' : 'Add expense')
            : (kitty ? 'Edit contribution' : 'Edit expense'),
        payerLabel: kitty ? 'Contributed by' : 'Paid by',
        people: _state.people,
        initial: initial,
        id: initial?.id ?? _state.nextId,
      ),
    );
    if (result == null || !mounted) return;
    _update((s) {
      final list = kitty ? s.funds : s.expenses;
      final next = initial == null
          ? [...list, result]
          : [for (final x in list) x.id == result.id ? result : x];
      return _with(
        s,
        expenses: kitty ? null : next,
        funds: kitty ? next : null,
        nextId: initial == null ? s.nextId + 1 : null,
      );
    });
  }

  void _deletePayment({required bool kitty, required Payment p}) {
    _update(
      (s) => _with(
        s,
        expenses: kitty ? null : [...s.expenses.where((x) => x.id != p.id)],
        funds: kitty ? [...s.funds.where((x) => x.id != p.id)] : null,
      ),
    );
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear trip data?'),
        content: const Text(
          'This removes all people, expenses and kitty contributions.',
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
      _state = const SplitState();
      _settled.clear();
    });
    unawaited(_store.clear());
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _settlementText(SettlementResult r) {
    final lines = [
      'Trip expense settlement',
      'Total shared pool: ${Fmt.money(r.pool)}',
      'Per person fair share: ${Fmt.money(r.fairShare)} (${_state.people.length} people)',
      '',
      'Member balances:',
      for (final m in r.balances)
        '• ${m.name}: paid ${Fmt.money(m.paid)} → ${m.balance > 0.01
            ? 'gets back ${Fmt.money(m.balance)}'
            : m.balance < -0.01
            ? 'owes ${Fmt.money(-m.balance)}'
            : 'settled up'}',
      '',
      if (r.transfers.isEmpty)
        'All expenses are settled up!'
      else ...[
        'Settlement transfers:',
        for (var i = 0; i < r.transfers.length; i++)
          '${i + 1}. ${r.transfers[i].fromName} pays ${r.transfers[i].toName}: ${Fmt.money(r.transfers[i].amount)}',
      ],
    ];
    return lines.join('\n');
  }

  String _quickText(QuickSplitResult q) {
    final lines = [
      'Bill split',
      'Base bill: ${Fmt.money(q.baseBill)}',
      if (_surcharge > 0)
        'Tax / service (${(_surcharge * 100).round()}%): ${Fmt.money(q.surchargeAmount)}',
      'Total bill: ${Fmt.money(q.totalBill)}',
      'People: ${q.pax}',
      'Per person: ${Fmt.money(q.perPerson)}',
      if (_rounding != SplitRounding.exact)
        '(Rounded: ${Fmt.money(q.perPerson)} × ${q.pax} = ${Fmt.money(q.roundedTotal)})',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Split'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: ScreenBody(
        children: [
          SegmentedButton<_Mode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Mode.settlement, label: Text('Settlement')),
              ButtonSegment(value: _Mode.quick, label: Text('Quick split')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          ..._mode == _Mode.quick ? _quick() : _settlement(),
          const Disclaimer('Estimates only — not financial advice.'),
        ],
      ),
    );
  }

  // ---- Quick split ----

  List<Widget> _quick() {
    final theme = Theme.of(context);
    final bill = parseNum(_bill.text);
    final billValid = bill != null && bill > 0;
    final error = _billTouched && !billValid ? 'Enter a valid amount' : null;
    final q = billValid
        ? calculateQuickSplit(
            bill: bill,
            pax: _pax,
            surcharge: _surcharge,
            rounding: _rounding,
          )
        : null;
    return [
      NumberField(
        label: 'Bill amount',
        controller: _bill,
        prefixText: Fmt.currencySymbol,
        errorText: error,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _billTouched = true),
      ),
      InputDecorator(
        decoration: const InputDecoration(labelText: 'Number of people'),
        child: Row(
          children: [
            IconButton.outlined(
              tooltip: 'Fewer people',
              icon: const Icon(Icons.remove),
              onPressed: _pax > 1 ? () => setState(() => _pax--) : null,
            ),
            Expanded(
              child: Text(
                '$_pax',
                textAlign: TextAlign.center,
                style: tabular(theme.textTheme.titleLarge),
              ),
            ),
            IconButton.outlined(
              tooltip: 'More people',
              icon: const Icon(Icons.add),
              onPressed: _pax < 99 ? () => setState(() => _pax++) : null,
            ),
          ],
        ),
      ),
      _ChipGroup<double>(
        title: 'Tax & service charge',
        options: _surcharges,
        selected: _surcharge,
        onSelected: (v) => setState(() => _surcharge = v),
      ),
      _ChipGroup<SplitRounding>(
        title: 'Rounding',
        options: _roundings,
        selected: _rounding,
        onSelected: (v) => setState(() => _rounding = v),
      ),
      if (q == null)
        _billTouched
            ? const EmptyState(
                icon: Icons.error_outline,
                message: 'Fix the highlighted fields to see results.',
              )
            : const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Enter a bill amount to split it.',
              )
      else ...[
        ResultHero(
          label: 'Each person pays',
          value: Fmt.money(q.perPerson),
          caption: 'Split by ${q.pax} ${q.pax == 1 ? 'person' : 'people'}',
        ),
        SectionCard(
          title: 'Breakdown',
          child: Column(
            children: [
              StatRow(label: 'Base bill', value: Fmt.money(q.baseBill)),
              if (_surcharge > 0)
                StatRow(
                  label: 'Tax / service charge',
                  value: Fmt.money(q.surchargeAmount),
                ),
              StatRow(label: 'Total bill', value: Fmt.money(q.totalBill)),
              if (_rounding != SplitRounding.exact)
                StatRow(
                  label: 'Total after rounding',
                  value: Fmt.money(q.roundedTotal),
                ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _copy(_quickText(q), 'Bill split copied'),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy breakdown'),
        ),
      ],
    ];
  }

  // ---- Settlement ----

  List<Widget> _settlement() {
    final people = _state.people;
    final r = calculateSettlement(
      people: people,
      expenses: _state.expenses,
      funds: _state.funds,
    );
    return [
      _peopleCard(),
      _paymentsCard(
        title: 'Expenses',
        addLabel: 'Add expense',
        empty: 'No expenses yet. Add what each person paid for.',
        kitty: false,
        payments: _state.expenses,
      ),
      _paymentsCard(
        title: 'Kitty contributions',
        addLabel: 'Add contribution',
        empty: 'No contributions yet. Add money put into the shared kitty.',
        kitty: true,
        payments: _state.funds,
      ),
      if (people.isEmpty)
        const EmptyState(
          icon: Icons.group_add_outlined,
          message: 'Add the people sharing the trip to see who owes whom.',
        )
      else
        ..._results(r),
    ];
  }

  Widget _peopleCard() {
    return SectionCard(
      title: 'People',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_state.people.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in _state.people)
                  InputChip(
                    label: Text(p.name),
                    deleteButtonTooltipMessage: 'Remove ${p.name}',
                    onDeleted: () => _removePerson(p),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newPerson,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addPerson(),
                  decoration: const InputDecoration(labelText: 'Add person'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Add person',
                icon: const Icon(Icons.add),
                onPressed: _addPerson,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentsCard({
    required String title,
    required String addLabel,
    required String empty,
    required bool kitty,
    required List<Payment> payments,
  }) {
    final theme = Theme.of(context);
    final addButton = FilledButton.tonal(
      onPressed: () => _editPayment(kitty: kitty),
      child: Text(addLabel),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 18;
    return SectionCard(
      title: title,
      trailing: largeText ? null : addButton,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (largeText) ...[addButton, const SizedBox(height: 8)],
          if (payments.isEmpty)
            Text(
              empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            const _TableHeader(),
            for (final p in payments)
              _PaymentRow(
                payment: p,
                payerName: _payerName(p.payerId),
                kitty: kitty,
                onTap: () => _editPayment(kitty: kitty, initial: p),
                onDelete: () => _deletePayment(kitty: kitty, p: p),
              ),
          ],
        ],
      ),
    );
  }

  String _payerName(int? id) {
    for (final p in _state.people) {
      if (p.id == id) return p.name;
    }
    return 'Unassigned';
  }

  List<Widget> _results(SettlementResult r) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = _state.people.length;
    return [
      ResultHero(
        label: 'Fair share per person',
        value: Fmt.money(r.fairShare),
        caption: 'Split between $n ${n == 1 ? 'person' : 'people'}',
      ),
      SectionCard(
        title: 'Summary',
        child: Column(
          children: [
            StatRow(label: 'Total shared pool', value: Fmt.money(r.pool)),
            StatRow(label: 'Members', value: '$n'),
          ],
        ),
      ),
      SectionCard(
        title: 'Member balances',
        child: Column(
          children: [
            for (final m in r.balances)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Text(m.name.characters.first.toUpperCase()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: theme.textTheme.bodyLarge),
                          Text(
                            'Paid: ${Fmt.money(m.paid)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      m.balance > 0.01
                          ? '+${Fmt.money(m.balance)} (gets back)'
                          : m.balance < -0.01
                          ? '-${Fmt.money(-m.balance)} (owes)'
                          : 'Settled',
                      textAlign: TextAlign.end,
                      style: tabular(
                        theme.textTheme.bodyMedium?.copyWith(
                          color: m.balance > 0.01
                              ? scheme.primary
                              : m.balance < -0.01
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      SectionCard(
        title: 'Settlement transfers (${r.transfers.length})',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.transfers.isEmpty)
              Text(
                r.pool > 0
                    ? 'All settled up!'
                    : 'Add expenses or contributions to see transfers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              for (final t in r.transfers) _transferTile(t),
              Text(
                'Tap a transfer to mark it as paid.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => _copy(_settlementText(r), 'Settlement summary copied'),
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy summary'),
      ),
    ];
  }

  Widget _transferTile(Transfer t) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = _settled.contains(t.key);
    final style = theme.textTheme.bodyLarge?.copyWith(
      decoration: done ? TextDecoration.lineThrough : null,
      color: done ? scheme.onSurfaceVariant : null,
    );
    return Semantics(
      checked: done,
      child: InkWell(
        onTap: () => setState(() {
          if (!_settled.remove(t.key)) _settled.add(t.key);
        }),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${t.fromName} → ${t.toName}',
                  style: style,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(Fmt.money(t.amount), style: tabular(style)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<(String, T)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in options)
              ChoiceChip(
                label: Text(label),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }
}

const _noteFlex = 30;
const _payerFlex = 26;
const _amountFlex = 28;
const _actionWidth = 48.0;

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: _noteFlex,
            child: Text('Note', style: style),
          ),
          Expanded(
            flex: _payerFlex,
            child: Text('By', style: style),
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
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.payerName,
    required this.kitty,
    required this.onTap,
    required this.onDelete,
  });

  final Payment payment;
  final String payerName;
  final bool kitty;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = payment.note.isEmpty
        ? (kitty ? 'Contribution' : 'Expense')
        : payment.note;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: _noteFlex,
              child: Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: _payerFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  payerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: _amountFlex,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  Fmt.money(payment.amount),
                  style: tabular(theme.textTheme.bodyMedium),
                ),
              ),
            ),
            SizedBox(
              width: _actionWidth,
              child: IconButton(
                tooltip: kitty ? 'Delete contribution' : 'Delete expense',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.title,
    required this.payerLabel,
    required this.people,
    required this.id,
    this.initial,
  });

  final String title;
  final String payerLabel;
  final List<Person> people;
  final int id;
  final Payment? initial;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : _plain(widget.initial!.amount),
  );
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late int? _payer = widget.people.any((p) => p.id == widget.initial?.payerId)
      ? widget.initial?.payerId
      : null;
  var _touched = false;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseNum(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _touched = true);
      return;
    }
    Navigator.pop(
      context,
      Payment(
        id: widget.id,
        amount: v,
        payerId: _payer,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = parseNum(_amount.text);
    final error = _touched && (v == null || v <= 0)
        ? 'Enter a valid amount'
        : null;
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
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            NumberField(
              label: 'Amount',
              controller: _amount,
              prefixText: Fmt.currencySymbol,
              errorText: error,
              onChanged: (_) => setState(() => _touched = true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _payer,
              decoration: InputDecoration(labelText: widget.payerLabel),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                for (final p in widget.people)
                  DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (id) => setState(() => _payer = id),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
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
