# MAB Calculator

A simple Go application for calculating the Monthly Average Balance (MAB) from a CSV file containing account transactions.

## Description

This tool reads a CSV file of financial transactions and calculates the average daily balance for a specified billing cycle. It's useful for determining the average balance maintained in an account over a month, which is often used by banks for calculating interest or determining if minimum balance requirements are met.

## Features

- Reads transaction data from a CSV file
- Calculates daily balances throughout the billing cycle
- Sorts transactions by date
- Computes the Monthly Average Balance (MAB)
- Displays detailed daily balance information

## Requirements

- Go 1.20 or later

## Installation

Clone the repository:

```bash
git clone https://github.com/yourusername/mab-calculator.git
cd mab-calculator
```

## Usage

1. Prepare your CSV file in the format:

```
Account,Date,Balance
"Start Amount","1 April, 2025",500.00
"Transaction Name","Date in format (DD Month, YYYY)",Amount
```

2. Make sure your CSV file is named `balances.csv` or update the `csvFile` variable in `main.go`.

3. Run the application:

```bash
go run main.go
```

## CSV File Format

The application expects a CSV file with the following structure:
- First row: Header row with column names
- Second row: Starting balance with the format `"Start Amount","Date",InitialBalance`
- Subsequent rows: Transactions with the format `"Name","Date",Amount`

Dates should be in the format `DD Month, YYYY` (e.g., "1 April, 2025").

## Example Output

```
Starting Balance: 500.00
Transaction: Transfer on 2025-04-30 for $150.00
Transaction: Food on 2025-04-30 for $-3.00

Daily Balances:
2025-04-01: $500.00
2025-04-02: $500.00
...
2025-04-30: $647.00

Average Daily Balance: $523.33
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## MoneyKit mobile app (Flutter, Android)

`mobile/` contains **MoneyKit**, a standalone offline Android app with four calculators built on the logic in this repo: **MAB** (port of `main.go`), **Interest**, **Mortgage** and **CPF interest**. No backend, no network permission.

- Spec and task breakdown: [`docs/PLAN.md`](docs/PLAN.md) · UI design: [`docs/UI_DESIGN.md`](docs/UI_DESIGN.md)
- QA: [`docs/QA_TEST_CASES.md`](docs/QA_TEST_CASES.md) · [`docs/QA_REPORT.md`](docs/QA_REPORT.md)
- Signed release APK is written to `dist/moneykit-1.0.0.apk` (git-ignored; rebuild with the command below)

```bash
cd mobile
flutter test                 # unit + widget tests
flutter build apk --release  # needs mobile/android/key.properties + keystore (git-ignored)
```

`mobile/android/key.properties` and `mobile/android/app/moneykit-release.jks` are the signing credentials. They are git-ignored; back them up, because the same key is needed for every future update of an installed app.
