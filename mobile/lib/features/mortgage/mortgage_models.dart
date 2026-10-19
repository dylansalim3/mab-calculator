class MortgageInput {
  const MortgageInput({
    required this.loanAmount,
    required this.annualRatePercent,
    required this.termYears,
    this.extraMonthlyPayment = 0,
    required this.startDate,
  });

  final double loanAmount;
  final double annualRatePercent;
  final int termYears;
  final double extraMonthlyPayment;

  /// Month the loan starts; payment k (1-based) falls in month start+k.
  final DateTime startDate;
}

class AmortizationRow {
  const AmortizationRow({
    required this.month,
    required this.date,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balance,
  });

  /// 1-based payment number.
  final int month;

  /// `DateTime(start.year, start.month + month, 1)`.
  final DateTime date;

  /// Total paid this month (scheduled + extra, truncated on the last payment).
  final double payment;
  final double principal;
  final double interest;

  /// Remaining balance after this payment.
  final double balance;
}

class MortgageResult {
  const MortgageResult({
    required this.monthlyPayment,
    required this.totalInterest,
    required this.totalPaid,
    required this.monthsToPayoff,
    required this.payoffDate,
    required this.baselineTotalInterest,
    required this.baselineMonths,
    required this.schedule,
  });

  /// Scheduled payment, excluding the extra payment.
  final double monthlyPayment;
  final double totalInterest;
  final double totalPaid;
  final int monthsToPayoff;

  /// Date of the final payment (== last schedule row date).
  final DateTime payoffDate;

  /// Same loan with extra = 0.
  final double baselineTotalInterest;
  final int baselineMonths;
  final List<AmortizationRow> schedule;

  double get interestSaved => baselineTotalInterest - totalInterest;
  int get monthsSaved => baselineMonths - monthsToPayoff;
}
