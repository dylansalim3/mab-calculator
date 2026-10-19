enum CpfAgeBand { below55, from55 }

/// Default CPF rates (percent p.a.). Single source of truth; see docs/PLAN.md A5.
class CpfDefaults {
  CpfDefaults._();
  static const oaRate = 2.5;
  static const saRaRate = 4.0;
  static const maRate = 4.0;
  static const oaExtraCap = 20000.0;
  static const extraBaseCapBelow55 = 60000.0;
  static const extraBaseCap55Plus = 30000.0;
}

class CpfInput {
  const CpfInput({
    required this.ageBand,
    this.oa = 0,
    this.saOrRa = 0,
    this.ma = 0,
    this.monthlyOa = 0,
    this.monthlySaOrRa = 0,
    this.monthlyMa = 0,
    this.oaRate = CpfDefaults.oaRate,
    this.saRaRate = CpfDefaults.saRaRate,
    this.maRate = CpfDefaults.maRate,
    required this.years,
  });

  final CpfAgeBand ageBand;

  /// Opening balances. [saOrRa] is the SA below 55, the RA at 55+.
  final double oa;
  final double saOrRa;
  final double ma;

  /// Monthly contributions, credited at month end.
  final double monthlyOa;
  final double monthlySaOrRa;
  final double monthlyMa;

  /// Percent p.a.
  final double oaRate;
  final double saRaRate;
  final double maRate;

  /// 1–40.
  final int years;
}

class CpfYearRow {
  const CpfYearRow({
    required this.year,
    required this.oaEnd,
    required this.saOrRaEnd,
    required this.maEnd,
    required this.basicInterest,
    required this.extraInterest,
  });

  /// 1-based.
  final int year;

  /// Balances after the 31 Dec credit.
  final double oaEnd;
  final double saOrRaEnd;
  final double maEnd;

  /// Interest credited this year.
  final double basicInterest;
  final double extraInterest;

  double get totalInterest => basicInterest + extraInterest;
  double get totalEnd => oaEnd + saOrRaEnd + maEnd;
}

class CpfResult {
  const CpfResult({required this.yearly});

  final List<CpfYearRow> yearly;

  CpfYearRow get last => yearly.last;
  double get finalOa => last.oaEnd;
  double get finalSaOrRa => last.saOrRaEnd;
  double get finalMa => last.maEnd;
  double get finalTotal => last.totalEnd;
  double get totalBasicInterest =>
      yearly.fold(0.0, (s, r) => s + r.basicInterest);
  double get totalExtraInterest =>
      yearly.fold(0.0, (s, r) => s + r.extraInterest);
  double get totalInterest => totalBasicInterest + totalExtraInterest;
}
