enum InterestType { simple, compound }

enum Compounding {
  annually(1, 'Annually'),
  semiAnnually(2, 'Semi-annually'),
  quarterly(4, 'Quarterly'),
  monthly(12, 'Monthly'),
  daily(365, 'Daily');

  const Compounding(this.perYear, this.label);
  final int perYear;
  final String label;
}

class InterestInput {
  const InterestInput({
    required this.principal,
    required this.annualRatePercent,
    required this.years,
    this.months = 0,
    this.type = InterestType.compound,
    this.compounding = Compounding.monthly,
    this.monthlyContribution = 0,
  });

  final double principal;
  final double annualRatePercent;
  final int years;
  final int months;
  final InterestType type;

  /// Ignored for [InterestType.simple].
  final Compounding compounding;

  /// Deposited at the end of every month.
  final double monthlyContribution;

  int get totalMonths => years * 12 + months;
}

class InterestYearRow {
  const InterestYearRow({
    required this.year,
    required this.months,
    required this.startBalance,
    required this.contributions,
    required this.interest,
    required this.endBalance,
  });

  /// 1-based projection year.
  final int year;

  /// Months covered by this row (12, or fewer for the final partial year).
  final int months;
  final double startBalance;
  final double contributions;
  final double interest;
  final double endBalance;
}

class InterestResult {
  const InterestResult({
    required this.finalBalance,
    required this.totalContributions,
    required this.totalInterest,
    required this.yearly,
    required this.monthlyBalances,
  });

  final double finalBalance;

  /// Excludes the opening principal.
  final double totalContributions;
  final double totalInterest;
  final List<InterestYearRow> yearly;

  /// Balance after each month: index 0 = start (principal), index n = after month n.
  /// Length = totalMonths + 1.
  final List<double> monthlyBalances;
}
