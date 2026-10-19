import 'package:flutter_test/flutter_test.dart';
import 'package:moneykit/features/mab/mab_csv.dart';

void main() {
  const header = 'Account,Date,Balance\n';

  test('parses the balances.csv sample', () {
    final r = parseMabCsv(
      '$header'
      '"Start Amount","1 April, 2025",500.00\n'
      '"Transfer","30 April, 2025",150.00\n'
      '"Food","30 April, 2025",-3.00',
    );
    expect(r.errors, isEmpty);
    final input = r.input!;
    expect(input.openingBalance, 500);
    expect(input.openingDate, DateTime(2025, 4, 1));
    expect(input.transactions, hasLength(2));
    expect(input.transactions[0].name, 'Transfer');
    expect(input.transactions[0].date, DateTime(2025, 4, 30));
    expect(input.transactions[0].amount, 150);
    expect(input.transactions[1].amount, -3);
  });

  test('quoted name containing a comma and doubled quotes', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",100\n'
      '"Smith, John","2 April, 2025",10\n'
      '"The ""Big"" one","3 April, 2025",20\n',
    );
    expect(r.errors, isEmpty);
    expect(r.input!.transactions[0].name, 'Smith, John');
    expect(r.input!.transactions[1].name, 'The "Big" one');
  });

  test('CRLF line endings', () {
    final r = parseMabCsv(
      'Account,Date,Balance\r\n'
      'Start,"1 April, 2025",100\r\n'
      'Tx,"2 April, 2025",5\r\n',
    );
    expect(r.errors, isEmpty);
    expect(r.input!.transactions, hasLength(1));
    expect(r.input!.transactions.single.amount, 5);
  });

  test('blank lines are skipped but row numbers keep counting', () {
    final r = parseMabCsv(
      '$header\n'
      'Start,"1 April, 2025",100\n'
      '   \n'
      'Tx,abc,5\n',
    );
    expect(r.input, isNotNull);
    expect(r.input!.transactions, isEmpty);
    expect(r.errors, ["Row 5: invalid date 'abc'"]);
  });

  test('trailing whitespace is trimmed', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",100   \n'
      'Tx , "2 April, 2025" ,  5 \n',
    );
    expect(r.errors, isEmpty);
    expect(r.input!.openingBalance, 100);
    expect(r.input!.transactions.single.name, 'Tx');
    expect(r.input!.transactions.single.amount, 5);
  });

  test('bad date is reported and parsing continues', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",100\n'
      'A,"2 April, 2025",1\n'
      'B,abc,2\n'
      'C,"4 April, 2025",3\n',
    );
    expect(r.errors, ["Row 4: invalid date 'abc'"]);
    expect(r.input!.transactions.map((t) => t.name), ['A', 'C']);
  });

  test('bad amount is reported and parsing continues', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",100\n'
      'A,"2 April, 2025",1\n'
      'B,"3 April, 2025",x\n'
      'C,"4 April, 2025",3\n',
    );
    expect(r.errors, ["Row 4: invalid amount 'x'"]);
    expect(r.input!.transactions.map((t) => t.name), ['A', 'C']);
  });

  test('impossible calendar date is invalid', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",100\n'
      'A,"31 April, 2025",1\n'
      'B,2025-02-30,1\n'
      'C,"1 Smarch, 2025",1\n',
    );
    expect(r.errors, [
      "Row 3: invalid date '31 April, 2025'",
      "Row 4: invalid date '2025-02-30'",
      "Row 5: invalid date '1 Smarch, 2025'",
    ]);
  });

  test('wrong column count', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",100\n'
      'A,"2 April, 2025"\n'
      'B,"3 April, 2025",1\n'
      'C,"4 April, 2025",1,extra\n',
    );
    expect(r.errors, [
      'Row 3: expected 3 columns',
      'Row 5: expected 3 columns',
    ]);
    expect(r.input!.transactions.single.name, 'B');
  });

  test('empty input', () {
    for (final text in ['', '   \n\n  ']) {
      final r = parseMabCsv(text);
      expect(r.input, isNull);
      expect(r.errors, ['No data found']);
    }
  });

  test('header only', () {
    final r = parseMabCsv('Account,Date,Balance');
    expect(r.input, isNull);
    expect(r.errors, ['No data found']);
  });

  test('unusable opening row yields no input', () {
    final r = parseMabCsv(
      '$header'
      'Start,not a date,100\n'
      'A,"2 April, 2025",1\n'
      'B,"3 April, 2025",y\n',
    );
    expect(r.input, isNull);
    expect(r.errors, [
      "Row 2: invalid date 'not a date'",
      "Row 4: invalid amount 'y'",
    ]);
  });

  test('opening row with bad amount or columns', () {
    var r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",abc\n',
    );
    expect(r.input, isNull);
    expect(r.errors, ["Row 2: invalid amount 'abc'"]);

    r = parseMabCsv('${header}Start,"1 April, 2025"\n');
    expect(r.input, isNull);
    expect(r.errors, ['Row 2: expected 3 columns']);
  });

  test('ISO date and lowercase month', () {
    final r = parseMabCsv(
      '$header'
      'Start,2025-04-01,100\n'
      'A,"2 april, 2025",1\n'
      'B,"3 APRIL, 2025",1\n'
      'C,2025-4-5,1\n',
    );
    expect(r.errors, isEmpty);
    expect(r.input!.openingDate, DateTime(2025, 4, 1));
    expect(r.input!.transactions.map((t) => t.date), [
      DateTime(2025, 4, 2),
      DateTime(2025, 4, 3),
      DateTime(2025, 4, 5),
    ]);
  });

  test('negative opening balance and thousands commas in quotes', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025","-1,234.50"\n'
      'A,"2 April, 2025","2,000.00"\n',
    );
    expect(r.errors, isEmpty);
    expect(r.input!.openingBalance, -1234.5);
    expect(r.input!.transactions.single.amount, 2000);
  });

  test('quoted field spanning lines keeps later row numbers correct', () {
    final r = parseMabCsv(
      '$header'
      'Start,"1 April, 2025",100\n'
      '"two\nlines","2 April, 2025",1\n'
      'B,abc,1\n',
    );
    expect(r.input!.transactions.single.name, 'two\nlines');
    expect(r.errors, ["Row 5: invalid date 'abc'"]);
  });
}
