import 'cpf_models.dart';

/// Spec: docs/PLAN.md §3.4.
CpfResult calculateCpf(CpfInput input) {
  var oa = input.oa;
  var saOrRa = input.saOrRa;
  var ma = input.ma;
  final rows = <CpfYearRow>[];

  for (var year = 1; year <= input.years; year++) {
    var oaInterest = 0.0;
    var saOrRaInterest = 0.0;
    var maInterest = 0.0;
    var extraInterest = 0.0;

    // Contributions land at month end, so each month's lowest balance is its
    // opening balance; accrued interest is only credited after December.
    for (var month = 0; month < 12; month++) {
      oaInterest += oa * input.oaRate / 12 / 100;
      saOrRaInterest += saOrRa * input.saRaRate / 12 / 100;
      maInterest += ma * input.maRate / 12 / 100;
      extraInterest += _monthlyExtraInterest(input.ageBand, oa, saOrRa, ma);

      oa += input.monthlyOa;
      saOrRa += input.monthlySaOrRa;
      ma += input.monthlyMa;
    }

    oa += oaInterest;
    saOrRa += saOrRaInterest + extraInterest;
    ma += maInterest;

    rows.add(
      CpfYearRow(
        year: year,
        oaEnd: oa,
        saOrRaEnd: saOrRa,
        maEnd: ma,
        basicInterest: oaInterest + saOrRaInterest + maInterest,
        extraInterest: extraInterest,
      ),
    );
  }

  return CpfResult(yearly: rows);
}

double _monthlyExtraInterest(
  CpfAgeBand ageBand,
  double oa,
  double saOrRa,
  double ma,
) {
  final base =
      (oa < CpfDefaults.oaExtraCap ? oa : CpfDefaults.oaExtraCap) + saOrRa + ma;
  if (ageBand == CpfAgeBand.below55) {
    final capped = base < CpfDefaults.extraBaseCapBelow55
        ? base
        : CpfDefaults.extraBaseCapBelow55;
    return capped * 1 / 12 / 100;
  }
  const cap = CpfDefaults.extraBaseCap55Plus;
  final first = base < cap ? base : cap;
  final rest = base > cap ? (base < 2 * cap ? base - cap : cap) : 0.0;
  return (first * 2 + rest * 1) / 12 / 100;
}
