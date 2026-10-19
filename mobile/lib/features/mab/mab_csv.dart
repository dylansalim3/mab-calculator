import '../../core/parse.dart';
import 'mab_models.dart';

const _months = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

final _longDate = RegExp(r'^(\d{1,2})\s+([A-Za-z]+),?\s*(\d{4})$');
final _isoDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');

/// Parses pasted CSV in the `balances.csv` format. Spec: docs/PLAN.md §3.1.
MabCsvResult parseMabCsv(String text) {
  final records = _readRecords(text);
  if (records.length < 2) {
    return const MabCsvResult(errors: ['No data found']);
  }

  final errors = <String>[];
  MabInput? input;
  double? openingBalance;
  DateTime? openingDate;
  final transactions = <MabTransaction>[];

  // records[0] is the header.
  for (var i = 1; i < records.length; i++) {
    final r = records[i];
    final isOpening = i == 1;
    if (r.fields.length != 3) {
      errors.add('Row ${r.row}: expected 3 columns');
      continue;
    }
    final name = r.fields[0];
    final date = _parseDate(r.fields[1]);
    final amount = parseNum(r.fields[2]);
    if (date == null) {
      errors.add("Row ${r.row}: invalid date '${r.fields[1]}'");
    }
    if (amount == null) {
      errors.add("Row ${r.row}: invalid amount '${r.fields[2]}'");
    }
    if (date == null || amount == null) continue;
    if (isOpening) {
      openingBalance = amount;
      openingDate = date;
    } else {
      transactions.add(MabTransaction(name: name, date: date, amount: amount));
    }
  }

  if (openingBalance != null && openingDate != null) {
    input = MabInput(
      openingBalance: openingBalance,
      openingDate: openingDate,
      transactions: transactions,
    );
  }
  return MabCsvResult(input: input, errors: errors);
}

DateTime? _parseDate(String s) {
  int year, month, day;
  final long = _longDate.firstMatch(s);
  final iso = _isoDate.firstMatch(s);
  if (long != null) {
    day = int.parse(long[1]!);
    month = _months.indexOf(long[2]!.toLowerCase()) + 1;
    year = int.parse(long[3]!);
  } else if (iso != null) {
    year = int.parse(iso[1]!);
    month = int.parse(iso[2]!);
    day = int.parse(iso[3]!);
  } else {
    return null;
  }
  if (month < 1 || month > 12 || day < 1) return null;
  final d = DateTime(year, month, day);
  return d.month == month ? d : null;
}

class _Record {
  _Record(this.row, this.fields);
  final int row;
  final List<String> fields;
}

/// RFC 4180-style reader. Fields are trimmed, blank lines are skipped and
/// `row` is the 1-based line on which the record starts.
List<_Record> _readRecords(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final records = <_Record>[];
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var inQuotes = false;
  var line = 1;
  var recordLine = 1;

  void endField() {
    fields.add(field.toString().trim());
    field.clear();
    quoted = false;
  }

  void endRecord() {
    endField();
    if (fields.length > 1 || fields.first.isNotEmpty) {
      records.add(_Record(recordLine, fields));
    }
    fields = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        if (c == '\n') line++;
        field.write(c);
      }
    } else if (c == '"' && !quoted && field.toString().trim().isEmpty) {
      field.clear();
      quoted = true;
      inQuotes = true;
    } else if (c == ',') {
      endField();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRecord();
      line++;
      recordLine = line;
    } else if (quoted && (c == ' ' || c == '\t')) {
      // Whitespace after a closing quote is dropped.
    } else {
      field.write(c);
    }
  }
  endRecord();
  return records;
}
