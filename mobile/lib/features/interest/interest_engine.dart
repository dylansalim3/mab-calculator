import 'dart:math' as math;

import 'interest_models.dart';

/// Spec: docs/PLAN.md §3.2.
InterestResult calculateInterest(InterestInput input) {
  final totalMonths = input.totalMonths;
  final principal = input.principal;
  final contribution = input.monthlyContribution;

  if (totalMonths <= 0) {
    return InterestResult(
      finalBalance: principal,
      totalContributions: 0.0,
      totalInterest: 0.0,
      yearly: const [],
      monthlyBalances: [principal],
    );
  }

  final r = input.annualRatePercent / 100.0;
  final isCompound = input.type == InterestType.compound;
  final m = input.compounding.perYear;
  final g = (r == 0) ? 1.0 : math.pow(1.0 + r / m, m / 12.0).toDouble();

  final monthlyBalances = List<double>.filled(totalMonths + 1, 0.0);
  monthlyBalances[0] = principal;

  var currentBal = principal;
  var contributionsSoFar = 0.0;
  var accruedInterest = 0.0;

  for (var month = 1; month <= totalMonths; month++) {
    if (isCompound) {
      final interest = r == 0 ? 0.0 : currentBal * (g - 1.0);
      currentBal += interest;
      currentBal += contribution;
      monthlyBalances[month] = currentBal;
    } else {
      final interest = r == 0
          ? 0.0
          : (principal + contributionsSoFar) * (r / 12.0);
      accruedInterest += interest;
      contributionsSoFar += contribution;
      currentBal = principal + contributionsSoFar + accruedInterest;
      monthlyBalances[month] = currentBal;
    }
  }

  final totalContributions = totalMonths * contribution;
  final finalBalance = monthlyBalances[totalMonths];
  var totalInterest = finalBalance - principal - totalContributions;
  if (totalInterest.abs() < 1e-12) totalInterest = 0.0;

  final yearCount = (totalMonths + 11) ~/ 12;
  final yearly = <InterestYearRow>[];

  for (var year = 1; year <= yearCount; year++) {
    final startMonth = (year - 1) * 12;
    final endMonth = math.min(year * 12, totalMonths);
    final rowMonths = endMonth - startMonth;
    final startBalance = monthlyBalances[startMonth];
    final endBalance = monthlyBalances[endMonth];
    final rowContributions = rowMonths * contribution;
    var rowInterest = endBalance - startBalance - rowContributions;
    if (rowInterest.abs() < 1e-12) rowInterest = 0.0;

    yearly.add(
      InterestYearRow(
        year: year,
        months: rowMonths,
        startBalance: startBalance,
        contributions: rowContributions,
        interest: rowInterest,
        endBalance: endBalance,
      ),
    );
  }

  return InterestResult(
    finalBalance: finalBalance,
    totalContributions: totalContributions,
    totalInterest: totalInterest,
    yearly: yearly,
    monthlyBalances: monthlyBalances,
  );
}
