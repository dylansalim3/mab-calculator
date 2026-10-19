import 'dart:math' as math;

import 'mortgage_models.dart';

/// Residue below this is float noise from the closed-form payment, not debt.
/// Scales with the loan because double error grows with magnitude.
double _epsilonFor(double loan) => math.max(1e-6, loan * 1e-12);

/// Spec: docs/PLAN.md §3.3.
MortgageResult calculateMortgage(MortgageInput input) {
  final n = input.termYears * 12;
  final r = input.annualRatePercent / 12 / 100;
  final payment = r == 0
      ? input.loanAmount / n
      : input.loanAmount * r / (1 - math.pow(1 + r, -n));

  final schedule = _amortize(input, r, payment, input.extraMonthlyPayment, n);
  final baseline = input.extraMonthlyPayment == 0
      ? schedule
      : _amortize(input, r, payment, 0, n);

  return MortgageResult(
    monthlyPayment: payment,
    totalInterest: _sum(schedule.map((row) => row.interest)),
    totalPaid: _sum(schedule.map((row) => row.payment)),
    monthsToPayoff: schedule.length,
    payoffDate: schedule.last.date,
    baselineTotalInterest: _sum(baseline.map((row) => row.interest)),
    baselineMonths: baseline.length,
    schedule: schedule,
  );
}

List<AmortizationRow> _amortize(
  MortgageInput input,
  double r,
  double payment,
  double extra,
  int termMonths,
) {
  final rows = <AmortizationRow>[];
  var balance = input.loanAmount;
  final epsilon = _epsilonFor(input.loanAmount);
  for (var k = 1; k <= termMonths + 1 && balance > 0; k++) {
    final interest = balance * r;
    var principal = math.min(payment + extra - interest, balance);
    if (balance - principal < epsilon) principal = balance;
    balance = principal == balance ? 0.0 : balance - principal;
    rows.add(
      AmortizationRow(
        month: k,
        date: DateTime(input.startDate.year, input.startDate.month + k, 1),
        payment: principal + interest,
        principal: principal,
        interest: interest,
        balance: balance,
      ),
    );
  }
  return rows;
}

double _sum(Iterable<double> values) => values.fold(0.0, (a, b) => a + b);
