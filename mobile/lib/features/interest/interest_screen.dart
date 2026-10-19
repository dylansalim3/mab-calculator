import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/parse.dart';
import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import 'interest_engine.dart';
import 'interest_models.dart';

const _invalidAmount = 'Enter a valid amount';
const _invalidRate = 'Enter a rate between 0 and 100';
const _invalidTerm = 'Enter a term between 1 month and 100 years';
const _emptyStateMessage =
    'Enter a principal and an interest rate to see your results.';
const _fixFieldsMessage = 'Fix the highlighted fields to see results.';
const _disclaimer = 'Estimates only — not financial advice.';

class InterestScreen extends StatefulWidget {
  const InterestScreen({super.key, this.embedded = false});

  /// True when hosted by the Calculators tab, which supplies the AppBar.
  final bool embedded;

  @override
  State<InterestScreen> createState() => _InterestScreenState();
}

class _InterestScreenState extends State<InterestScreen> {
  InterestType _type = InterestType.compound;
  Compounding _compounding = Compounding.monthly;

  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _years = TextEditingController(text: '10');
  final _months = TextEditingController(text: '0');
  final _contribution = TextEditingController();

  final _touched = <TextEditingController>{};

  late final _all = [_principal, _rate, _years, _months, _contribution];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _edited(TextEditingController c) => setState(() => _touched.add(c));

  double? get _parsedPrincipal {
    final text = _principal.text.trim();
    if (text.isEmpty) return null;
    final v = parseNum(text);
    return (v != null && v >= 0) ? v : null;
  }

  double? get _parsedRate {
    final text = _rate.text.trim();
    if (text.isEmpty) return null;
    final v = parseNum(text);
    return (v != null && v >= 0 && v <= 100) ? v : null;
  }

  int? get _parsedYears {
    final text = _years.text.trim();
    if (text.isEmpty) return null;
    final v = parseNum(text);
    if (v == null || v != v.truncateToDouble() || v < 0) return null;
    return v.toInt();
  }

  int? get _parsedMonths {
    final text = _months.text.trim();
    if (text.isEmpty) return null;
    final v = parseNum(text);
    if (v == null || v != v.truncateToDouble() || v < 0) return null;
    return v.toInt();
  }

  bool get _isTermValid {
    final y = _parsedYears;
    final m = _parsedMonths;
    if (y == null || m == null) return false;
    final totalMonths = y * 12 + m;
    return totalMonths >= 1 && totalMonths <= 1200;
  }

  double? get _parsedContribution {
    final text = _contribution.text.trim();
    if (text.isEmpty) return 0.0;
    final v = parseNum(text);
    return (v != null && v >= 0) ? v : null;
  }

  String? _principalError() {
    if (!_touched.contains(_principal)) return null;
    return _parsedPrincipal == null ? _invalidAmount : null;
  }

  String? _rateError() {
    if (!_touched.contains(_rate)) return null;
    return _parsedRate == null ? _invalidRate : null;
  }

  String? _yearsError() {
    if (!_touched.contains(_years)) return null;
    if (_parsedYears == null || !_isTermValid) return _invalidTerm;
    return null;
  }

  String? _monthsError() {
    if (!_touched.contains(_months)) return null;
    if (_parsedMonths == null) {
      return _yearsError() == null ? _invalidTerm : null;
    }
    if (!_isTermValid && !_touched.contains(_years)) {
      return _invalidTerm;
    }
    return null;
  }

  String? _contributionError() {
    if (!_touched.contains(_contribution)) return null;
    return _parsedContribution == null ? _invalidAmount : null;
  }

  bool get _hasVisibleErrors =>
      _principalError() != null ||
      _rateError() != null ||
      _yearsError() != null ||
      _monthsError() != null ||
      _contributionError() != null;

  bool get _isValid =>
      _parsedPrincipal != null &&
      _parsedRate != null &&
      _isTermValid &&
      _parsedContribution != null;

  InterestResult? _calculate() {
    if (!_isValid) return null;
    return calculateInterest(
      InterestInput(
        principal: _parsedPrincipal!,
        annualRatePercent: _parsedRate!,
        years: _parsedYears!,
        months: _parsedMonths!,
        type: _type,
        compounding: _compounding,
        monthlyContribution: _parsedContribution!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _calculate();
    final principal = _parsedPrincipal;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Interest Calculator')),
      body: ScreenBody(
        children: [
          SegmentedButton<InterestType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: InterestType.simple, label: Text('Simple')),
              ButtonSegment(
                value: InterestType.compound,
                label: Text('Compound'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          NumberField(
            label: 'Principal',
            controller: _principal,
            prefixText: Fmt.currencySymbol,
            errorText: _principalError(),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _edited(_principal),
          ),
          NumberField(
            label: 'Annual interest rate',
            controller: _rate,
            suffixText: '%',
            errorText: _rateError(),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _edited(_rate),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NumberField(
                  label: 'Years',
                  controller: _years,
                  errorText: _yearsError(),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _edited(_years),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumberField(
                  label: 'Months',
                  controller: _months,
                  errorText: _monthsError(),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _edited(_months),
                ),
              ),
            ],
          ),
          if (_type == InterestType.compound)
            DropdownButtonFormField<Compounding>(
              initialValue: _compounding,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Compounding'),
              items: [
                for (final c in Compounding.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) {
                if (c != null) setState(() => _compounding = c);
              },
            ),
          NumberField(
            label: 'Monthly contribution (optional)',
            controller: _contribution,
            prefixText: Fmt.currencySymbol,
            errorText: _contributionError(),
            textInputAction: TextInputAction.done,
            onChanged: (_) => _edited(_contribution),
          ),
          if (result == null) ...[
            if (_hasVisibleErrors)
              const InlineBanner(message: _fixFieldsMessage, isError: true)
            else
              const EmptyState(
                icon: Icons.trending_up,
                message: _emptyStateMessage,
              ),
          ] else ...[
            ResultHero(
              label: 'Final balance',
              value: Fmt.money(result.finalBalance),
            ),
            SectionCard(
              title: 'Summary',
              child: Column(
                children: [
                  StatRow(
                    label: 'Initial principal',
                    value: Fmt.money(principal!),
                  ),
                  StatRow(
                    label: 'Total contributions',
                    value: Fmt.money(result.totalContributions),
                  ),
                  StatRow(
                    label: 'Total interest',
                    value: Fmt.money(result.totalInterest),
                    emphasize: true,
                  ),
                  if (result.finalBalance > 0) ...[
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final scale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1.0);
                        final targetWidth =
                            math.max(constraints.maxWidth, 360.0) * scale;
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: targetWidth,
                            child: SplitBar(
                              parts: [
                                SplitPart(
                                  'Principal',
                                  principal,
                                  scheme.primary,
                                ),
                                SplitPart(
                                  'Contributions',
                                  result.totalContributions,
                                  scheme.secondary,
                                ),
                                SplitPart(
                                  'Interest',
                                  result.totalInterest,
                                  scheme.tertiary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            SectionCard(
              title: 'Growth over time',
              child: SimpleLineChart(
                values: result.monthlyBalances,
                xLabel: (index) {
                  if (index % 12 == 0) {
                    return '${index ~/ 12}y';
                  }
                  final s = (index / 12).toStringAsFixed(1);
                  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}y';
                },
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

  final List<InterestYearRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final cell = tabular(theme.textTheme.bodyMedium);
    final hasPartial = rows.any((r) => r.months < 12);

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
              0: FixedColumnWidth(56),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                children: [
                  text('Year', header, end: false),
                  text('Interest', header),
                  text('Balance', header),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    text(
                      '${r.year}${r.months < 12 ? '*' : ''}',
                      cell,
                      end: false,
                    ),
                    text(Fmt.money(r.interest), cell),
                    text(Fmt.money(r.endBalance), cell),
                  ],
                ),
            ],
          ),
          if (hasPartial)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '* partial year',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
