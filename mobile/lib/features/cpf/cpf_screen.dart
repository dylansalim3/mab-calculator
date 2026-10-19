import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/parse.dart';
import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import 'cpf_engine.dart';
import 'cpf_models.dart';

const _invalidAmount = 'Enter a valid amount';
const _invalidRate = 'Enter a rate between 0 and 10';
const _invalidYears = 'Enter 1 to 40 years';
const _disclaimer =
    'Estimates only. Interest is calculated monthly on the lowest balance, credited every 31 Dec, and extra interest goes to your SA (below 55) or RA (55 and above). Projection assumes it starts on 1 Jan. Check cpf.gov.sg for current rates.';

String _rateText(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class CpfScreen extends StatefulWidget {
  const CpfScreen({super.key, this.embedded = false});

  /// True when hosted by the Calculators tab, which supplies the AppBar.
  final bool embedded;

  @override
  State<CpfScreen> createState() => _CpfScreenState();
}

class _CpfScreenState extends State<CpfScreen> {
  CpfAgeBand _band = CpfAgeBand.below55;

  final _oa = TextEditingController();
  final _saRa = TextEditingController();
  final _ma = TextEditingController();
  final _monthlyOa = TextEditingController();
  final _monthlySaRa = TextEditingController();
  final _monthlyMa = TextEditingController();
  final _oaRate = TextEditingController(text: _rateText(CpfDefaults.oaRate));
  final _saRaRate = TextEditingController(
    text: _rateText(CpfDefaults.saRaRate),
  );
  final _maRate = TextEditingController(text: _rateText(CpfDefaults.maRate));
  final _years = TextEditingController(text: '5');

  final _touched = <TextEditingController>{};

  late final _all = [
    _oa, _saRa, _ma, _monthlyOa, _monthlySaRa, _monthlyMa, //
    _oaRate, _saRaRate, _maRate, _years,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _is55 => _band == CpfAgeBand.from55;

  /// Blank counts as 0; null means invalid.
  double? _amount(TextEditingController c) {
    if (c.text.trim().isEmpty) return 0;
    final v = parseNum(c.text);
    return v != null && v >= 0 ? v : null;
  }

  double? _rate(TextEditingController c) {
    final v = parseNum(c.text);
    return v != null && v >= 0 && v <= 10 ? v : null;
  }

  int? _yearsValue() {
    final v = parseNum(_years.text);
    if (v == null || v != v.truncateToDouble() || v < 1 || v > 40) return null;
    return v.toInt();
  }

  String? _error(TextEditingController c, bool valid, String message) =>
      _touched.contains(c) && !valid ? message : null;

  Widget _amountField(
    String label,
    TextEditingController c, {
    TextInputAction action = TextInputAction.next,
  }) {
    return NumberField(
      label: label,
      controller: c,
      prefixText: Fmt.currencySymbol,
      errorText: _error(c, _amount(c) != null, _invalidAmount),
      textInputAction: action,
      onChanged: (_) => _edited(c),
    );
  }

  Widget _rateField(String label, TextEditingController c) {
    return NumberField(
      label: label,
      controller: c,
      suffixText: '%',
      errorText: _error(c, _rate(c) != null, _invalidRate),
      onChanged: (_) => _edited(c),
    );
  }

  void _edited(TextEditingController c) => setState(() => _touched.add(c));

  void _resetRates() {
    setState(() {
      _oaRate.text = _rateText(CpfDefaults.oaRate);
      _saRaRate.text = _rateText(CpfDefaults.saRaRate);
      _maRate.text = _rateText(CpfDefaults.maRate);
      _touched.removeAll([_oaRate, _saRaRate, _maRate]);
    });
  }

  Widget _expansionCard(String title, List<Widget> children) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(title),
        shape: const Border(),
        collapsedShape: const Border(),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saRaName = _is55 ? 'Retirement Account (RA)' : 'Special Account (SA)';
    final saRaShort = _is55 ? 'RA' : 'SA';

    final oa = _amount(_oa);
    final saRa = _amount(_saRa);
    final ma = _amount(_ma);
    final mOa = _amount(_monthlyOa);
    final mSaRa = _amount(_monthlySaRa);
    final mMa = _amount(_monthlyMa);
    final oaRate = _rate(_oaRate);
    final saRaRate = _rate(_saRaRate);
    final maRate = _rate(_maRate);
    final years = _yearsValue();

    final valid = [
      oa,
      saRa,
      ma,
      mOa,
      mSaRa,
      mMa,
      oaRate,
      saRaRate,
      maRate,
      years,
    ].every((v) => v != null);
    final result = valid
        ? calculateCpf(
            CpfInput(
              ageBand: _band,
              oa: oa!,
              saOrRa: saRa!,
              ma: ma!,
              monthlyOa: mOa!,
              monthlySaOrRa: mSaRa!,
              monthlyMa: mMa!,
              oaRate: oaRate!,
              saRaRate: saRaRate!,
              maRate: maRate!,
              years: years!,
            ),
          )
        : null;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('CPF Interest Calculator')),
      body: ScreenBody(
        children: [
          SegmentedButton<CpfAgeBand>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: CpfAgeBand.below55, label: Text('Below 55')),
              ButtonSegment(
                value: CpfAgeBand.from55,
                label: Text('55 & above'),
              ),
            ],
            selected: {_band},
            onSelectionChanged: (s) => setState(() => _band = s.first),
          ),
          SectionCard(
            title: 'Current balances',
            child: Column(
              children: [
                _amountField('Ordinary Account (OA)', _oa),
                const SizedBox(height: 12),
                _amountField(saRaName, _saRa),
                const SizedBox(height: 12),
                _amountField('MediSave Account (MA)', _ma),
              ],
            ),
          ),
          _expansionCard('Monthly contributions (optional)', [
            _amountField('OA contribution', _monthlyOa),
            _amountField('$saRaShort contribution', _monthlySaRa),
            _amountField('MA contribution', _monthlyMa),
          ]),
          _expansionCard('Interest rates (editable)', [
            _rateField('OA rate', _oaRate),
            _rateField('SA/RA rate', _saRaRate),
            _rateField('MA rate', _maRate),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetRates,
                child: const Text('Reset to defaults'),
              ),
            ),
          ]),
          NumberField(
            label: 'Projection years',
            controller: _years,
            errorText: _error(_years, years != null, _invalidYears),
            textInputAction: TextInputAction.done,
            onChanged: (_) => _edited(_years),
          ),
          if (result == null)
            const InlineBanner(
              message: 'Fix the highlighted fields to see results.',
              isError: true,
            )
          else ...[
            ResultHero(
              label:
                  'Total CPF balance after $years ${years == 1 ? 'year' : 'years'}',
              value: Fmt.money(result.finalTotal),
            ),
            SectionCard(
              title: 'Summary',
              child: Column(
                children: [
                  StatRow(
                    label: 'Total interest earned',
                    value: Fmt.money(result.totalInterest),
                    emphasize: true,
                  ),
                  StatRow(
                    label: 'Basic interest',
                    value: Fmt.money(result.totalBasicInterest),
                  ),
                  StatRow(
                    label: 'Extra interest',
                    value: Fmt.money(result.totalExtraInterest),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Final balances',
              child: Column(
                children: [
                  StatRow(
                    label: 'Ordinary Account (OA)',
                    value: Fmt.money(result.finalOa),
                  ),
                  StatRow(
                    label: saRaName,
                    value: Fmt.money(result.finalSaOrRa),
                  ),
                  StatRow(
                    label: 'MediSave Account (MA)',
                    value: Fmt.money(result.finalMa),
                  ),
                ],
              ),
            ),
            _YearTable(rows: result.yearly),
          ],
          const Disclaimer(_disclaimer),
        ],
      ),
    );
  }
}

class _YearTable extends StatelessWidget {
  const _YearTable({required this.rows});

  final List<CpfYearRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final cell = tabular(theme.textTheme.bodyMedium);

    Widget text(String s, TextStyle? style, {bool end = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: end ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(s, style: style),
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text('Year by year'),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Table(
            columnWidths: const {
              0: FixedColumnWidth(48),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                children: [
                  text('Year', header, end: false),
                  text('Interest', header),
                  text('Total balance', header),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    text('${r.year}', cell, end: false),
                    text(Fmt.money(r.totalInterest), cell),
                    text(Fmt.money(r.totalEnd), cell),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
