/// Parses user-typed numbers: tolerates thousands commas and surrounding spaces.
/// Returns null for empty / unparsable / non-finite input.
double? parseNum(String? text) {
  if (text == null) return null;
  final cleaned = text.replaceAll(',', '').replaceAll(' ', '').trim();
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

/// Date-only value (local midnight).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
