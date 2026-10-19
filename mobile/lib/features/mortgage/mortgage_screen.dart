import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/parse.dart';
import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import 'mortgage_engine.dart';
import 'mortgage_models.dart';

const _invalidAmount = 'Enter a valid amount';
const _downPaymentTooHigh = 'Down payment must be less than the price';
const _invalidRate = 'Enter a rate between 0 and 30';
const _invalidTerm = 'Enter a term between 1 and 40 years';
const _disclaimer = 'Estimates only — not financial advice.';
const _fixHighlightedFields = 'Fix the highlighted fields to see results.';
const _emptyStateMessage =
    'Enter a loan amount and an interest rate to see your monthly payment.';

enum MortgageMode { loanAmount, propertyPrice }

enum DownPaymentType { dollar, percent }

enum ScheduleView { yearly, monthly }

class MortgageScreen extends StatefulWidget {
  const MortgageScreen({super.key, this.embedded = false});

  /// True when hosted by the Calculators tab, which supplies the AppBar.
  final bool embedded;

  @override
  State<MortgageScreen> createState() => _MortgageScreenState();
}

class _MortgageScreenState extends State<MortgageScreen> {
  MortgageMode _mode = MortgageMode.loanAmount;
  DownPaymentType _downPaymentType = DownPaymentType.percent;
  ScheduleView _scheduleView = ScheduleView.yearly;

  final _loanAmount = TextEditingController();
  final _propertyPrice = TextEditingController();
  final _downPayment = TextEditingController();
  final _rate = TextEditingController();
  final _term = TextEditingController(text: '25');
  final _extra = TextEditingController();

  final _touched = <TextEditingController>{};

  late final _all = [
    _loanAmount,
    _propertyPrice,
    _downPayment,
    _rate,
    _term,
    _extra,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _edited(TextEditingController c) => setState(() => _touched.add(c));

  Widget _buildScheduleRow({
    required String col1,
    required String col2,
    required String col3,
    required String col4,
    required TextStyle? style,
    bool isLast = false,
    required Color cardColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : null,
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, isLast ? 16 : 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(col1, style: style),
            ),
          ),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(col2, style: style),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(col3, style: style),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(col4, style: style),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceContainerLow;
    final headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final cellStyle = tabular(theme.textTheme.bodyMedium);

    // Rate validation
    final rateRaw = parseNum(_rate.text);
    final isRateValid = rateRaw != null && rateRaw >= 0 && rateRaw <= 30;
    final rateError = _touched.contains(_rate) && !isRateValid
        ? _invalidRate
        : null;
    final effectiveRate = isRateValid ? rateRaw : null;

    // Term validation
    final termRaw = parseNum(_term.text);
    final isTermValid =
        termRaw != null &&
        termRaw == termRaw.truncateToDouble() &&
        termRaw >= 1 &&
        termRaw <= 40;
    final termError = _touched.contains(_term) && !isTermValid
        ? _invalidTerm
        : null;
    final effectiveTerm = isTermValid ? termRaw.toInt() : null;

    // Extra payment validation (blank = 0)
    final extraText = _extra.text.trim();
    double? effectiveExtra;
    String? extraError;
    if (extraText.isEmpty) {
      effectiveExtra = 0.0;
    } else {
      final extraRaw = parseNum(extraText);
      if (extraRaw == null || extraRaw < 0) {
        if (_touched.contains(_extra)) {
          extraError = _invalidAmount;
        }
      } else {
        effectiveExtra = extraRaw;
      }
    }

    // Loan amount mode vs Property price mode
    double? effectiveLoan;
    String? loanError;
    String? priceError;
    String? downPaymentError;
    String? derivedCaption;

    if (_mode == MortgageMode.loanAmount) {
      final loanRaw = parseNum(_loanAmount.text);
      final isLoanValid = loanRaw != null && loanRaw > 0;
      loanError = _touched.contains(_loanAmount) && !isLoanValid
          ? _invalidAmount
          : null;
      effectiveLoan = isLoanValid ? loanRaw : null;
    } else {
      final priceRaw = parseNum(_propertyPrice.text);
      final isPriceValid = priceRaw != null && priceRaw > 0;
      priceError = _touched.contains(_propertyPrice) && !isPriceValid
          ? _invalidAmount
          : null;

      double? downPaymentDollars;
      final downRaw = parseNum(_downPayment.text);

      if (_touched.contains(_downPayment)) {
        if (downRaw == null || downRaw < 0) {
          downPaymentError = _invalidAmount;
        }
      }

      if (downRaw != null && downRaw >= 0) {
        if (_downPaymentType == DownPaymentType.percent) {
          if (downRaw >= 100) {
            if (_touched.contains(_downPayment)) {
              downPaymentError = _downPaymentTooHigh;
            }
          } else if (isPriceValid) {
            downPaymentDollars = priceRaw * (downRaw / 100.0);
          }
        } else {
          if (isPriceValid && downRaw >= priceRaw) {
            if (_touched.contains(_downPayment)) {
              downPaymentError = _downPaymentTooHigh;
            }
          } else {
            downPaymentDollars = downRaw;
          }
        }
      }

      if (isPriceValid &&
          downPaymentDollars != null &&
          downPaymentDollars < priceRaw) {
        effectiveLoan = priceRaw - downPaymentDollars;
        derivedCaption = 'Loan amount: ${Fmt.money(effectiveLoan)}';
      }
    }

    final bool hasErrors;
    if (_mode == MortgageMode.loanAmount) {
      hasErrors =
          loanError != null ||
          rateError != null ||
          termError != null ||
          extraError != null;
    } else {
      hasErrors =
          priceError != null ||
          downPaymentError != null ||
          rateError != null ||
          termError != null ||
          extraError != null;
    }

    final hasAllValidInputs =
        effectiveLoan != null &&
        effectiveRate != null &&
        effectiveTerm != null &&
        effectiveExtra != null;

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);

    final MortgageResult? result = hasAllValidInputs
        ? calculateMortgage(
            MortgageInput(
              loanAmount: effectiveLoan,
              annualRatePercent: effectiveRate,
              termYears: effectiveTerm,
              extraMonthlyPayment: effectiveExtra,
              startDate: startDate,
            ),
          )
        : null;

    final yearlyRows = result != null
        ? _aggregateYearly(result.schedule)
        : const <_YearlyRow>[];
    final isYearly = _scheduleView == ScheduleView.yearly;
    final scheduleCount = result == null
        ? 0
        : (isYearly ? yearlyRows.length : result.schedule.length);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Mortgage Calculator')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SegmentedButton<MortgageMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: MortgageMode.loanAmount,
                          label: Text('Loan amount'),
                        ),
                        ButtonSegment(
                          value: MortgageMode.propertyPrice,
                          label: Text('Property price'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 12),
                    if (_mode == MortgageMode.loanAmount) ...[
                      NumberField(
                        label: 'Loan amount',
                        controller: _loanAmount,
                        prefixText: Fmt.currencySymbol,
                        errorText: loanError,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _edited(_loanAmount),
                      ),
                    ] else ...[
                      NumberField(
                        label: 'Property price',
                        controller: _propertyPrice,
                        prefixText: Fmt.currencySymbol,
                        errorText: priceError,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _edited(_propertyPrice),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: NumberField(
                              label: 'Down payment',
                              controller: _downPayment,
                              prefixText:
                                  _downPaymentType == DownPaymentType.dollar
                                  ? Fmt.currencySymbol
                                  : null,
                              suffixText:
                                  _downPaymentType == DownPaymentType.percent
                                  ? '%'
                                  : null,
                              errorText: downPaymentError,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => _edited(_downPayment),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SegmentedButton<DownPaymentType>(
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: DownPaymentType.dollar,
                                  label: Text(r'$'),
                                ),
                                ButtonSegment(
                                  value: DownPaymentType.percent,
                                  label: Text('%'),
                                ),
                              ],
                              selected: {_downPaymentType},
                              onSelectionChanged: (s) =>
                                  setState(() => _downPaymentType = s.first),
                            ),
                          ),
                        ],
                      ),
                      if (derivedCaption != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          derivedCaption,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    NumberField(
                      label: 'Annual interest rate',
                      controller: _rate,
                      suffixText: '%',
                      errorText: rateError,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _edited(_rate),
                    ),
                    const SizedBox(height: 12),
                    NumberField(
                      label: 'Loan term (years)',
                      controller: _term,
                      errorText: termError,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _edited(_term),
                    ),
                    const SizedBox(height: 12),
                    NumberField(
                      label: 'Extra monthly payment (optional)',
                      controller: _extra,
                      prefixText: Fmt.currencySymbol,
                      errorText: extraError,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _edited(_extra),
                    ),
                    const SizedBox(height: 12),
                    if (result == null) ...[
                      if (hasErrors)
                        const InlineBanner(
                          message: _fixHighlightedFields,
                          isError: true,
                        )
                      else
                        const EmptyState(
                          icon: Icons.home_outlined,
                          message: _emptyStateMessage,
                        ),
                    ] else ...[
                      ResultHero(
                        label: 'Monthly payment',
                        value: Fmt.money(result.monthlyPayment),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Summary',
                        child: Column(
                          children: [
                            StatRow(
                              label: 'Loan amount',
                              value: Fmt.money(effectiveLoan!),
                            ),
                            StatRow(
                              label: 'Total interest',
                              value: Fmt.money(result.totalInterest),
                            ),
                            StatRow(
                              label: 'Total paid',
                              value: Fmt.money(result.totalPaid),
                            ),
                            StatRow(
                              label: 'Payoff date',
                              value: Fmt.monthYear(result.payoffDate),
                            ),
                            StatRow(
                              label: 'Loan term',
                              value: Fmt.duration(result.monthsToPayoff),
                            ),
                          ],
                        ),
                      ),
                      if (effectiveExtra! > 0) ...[
                        const SizedBox(height: 12),
                        SectionCard(
                          title: 'With extra payments',
                          child: Column(
                            children: [
                              StatRow(
                                label: 'Interest saved',
                                value: Fmt.money(result.interestSaved),
                              ),
                              StatRow(
                                label: 'Time saved',
                                value: Fmt.duration(result.monthsSaved),
                              ),
                              StatRow(
                                label: 'New payoff date',
                                value: Fmt.monthYear(result.payoffDate),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SplitBar(
                            parts: [
                              SplitPart(
                                'Principal',
                                effectiveLoan,
                                theme.colorScheme.primary,
                              ),
                              SplitPart(
                                'Interest',
                                result.totalInterest,
                                theme.colorScheme.tertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Amortisation schedule',
                                  style: theme.textTheme.titleMedium,
                                ),
                                SegmentedButton<ScheduleView>(
                                  showSelectedIcon: false,
                                  style: const ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: ScheduleView.yearly,
                                      label: Text('Yearly'),
                                    ),
                                    ButtonSegment(
                                      value: ScheduleView.monthly,
                                      label: Text('Monthly'),
                                    ),
                                  ],
                                  selected: {_scheduleView},
                                  onSelectionChanged: (s) =>
                                      setState(() => _scheduleView = s.first),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    isYearly ? 'Year' : '#',
                                    style: headerStyle,
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Principal',
                                    style: headerStyle,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Interest',
                                    style: headerStyle,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Balance',
                                    style: headerStyle,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
              if (result != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: scheduleCount,
                    itemBuilder: (context, i) {
                      final isLast = i == scheduleCount - 1;
                      if (isYearly) {
                        final r = yearlyRows[i];
                        return _buildScheduleRow(
                          col1: '${r.year}',
                          col2: Fmt.money(r.principal),
                          col3: Fmt.money(r.interest),
                          col4: Fmt.money(r.balance),
                          style: cellStyle,
                          isLast: isLast,
                          cardColor: cardColor,
                        );
                      } else {
                        final r = result.schedule[i];
                        return _buildScheduleRow(
                          col1: '${r.month}',
                          col2: Fmt.money(r.principal),
                          col3: Fmt.money(r.interest),
                          col4: Fmt.money(r.balance),
                          style: cellStyle,
                          isLast: isLast,
                          cardColor: cardColor,
                        );
                      }
                    },
                  ),
                ),
              const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: Disclaimer(_disclaimer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearlyRow {
  const _YearlyRow({
    required this.year,
    required this.principal,
    required this.interest,
    required this.balance,
  });

  final int year;
  final double principal;
  final double interest;
  final double balance;
}

List<_YearlyRow> _aggregateYearly(List<AmortizationRow> schedule) {
  if (schedule.isEmpty) return const [];
  final rows = <_YearlyRow>[];
  final totalMonths = schedule.length;
  final numYears = (totalMonths + 11) ~/ 12;

  for (var y = 1; y <= numYears; y++) {
    final start = (y - 1) * 12;
    final end = math.min(y * 12, totalMonths);
    var principal = 0.0;
    var interest = 0.0;
    for (var i = start; i < end; i++) {
      principal += schedule[i].principal;
      interest += schedule[i].interest;
    }
    final balance = schedule[end - 1].balance;
    rows.add(
      _YearlyRow(
        year: y,
        principal: principal,
        interest: interest,
        balance: balance,
      ),
    );
  }
  return rows;
}
