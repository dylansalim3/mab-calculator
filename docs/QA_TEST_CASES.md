# MoneyKit — Black-box QA test cases

Derived only from `PLAN.md` §3 (golden vectors) and `UI_DESIGN.md` §3, §5, §7, §8, §9. No source code was read.
Target: release APK `/Users/dylansalim-ola/Documents/Personal/mab-calculator/dist/moneykit-1.0.0.apk` (package `com.dylansalim.moneykit`) on emulator `emulator-5554` (Pixel_9_Pro, Android 16).

Priority: **P0** = core numbers and crash-free · **P1** = validation / state / UX contract · **P2** = visual / edge.
Conventions: "fresh" = after `Reset > Clear` (or first launch with cleared data). Money is `$1,234.56`, negatives `-$1,234.56`. Values are read from the accessibility tree (text / content-desc such as `Final balance: $16,470.09`). MAB dates that are not "today" are entered through Import CSV (UI_DESIGN §7.1) unless the case is about the date picker. Today on the emulator is in Oct 2026 (default Opening date).
Derived (not in spec) expected values were calculated independently with the spec algorithms and are marked (derived).

## 1. General / platform

| ID | Pri | Area | Preconditions | Steps | Expected |
|---|---|---|---|---|---|
| GEN-01 | P0 | Launch | APK reinstalled with `adb install -r` | Launch via monkey | App starts on MAB tab; AppBar title `MAB Calculator`; no crash dialog; process alive |
| GEN-02 | P0 | Packaging | APK | `aapt2 dump badging` | Label `MoneyKit`, package `com.dylansalim.moneykit`, a launcher icon entry present |
| GEN-03 | P0 | Packaging | APK | Inspect `uses-permission` in badging | No `android.permission.INTERNET` |
| GEN-04 | P0 | Crash log | After full run | `adb logcat -d -s AndroidRuntime:E flutter:E` | No FATAL EXCEPTION, no Flutter framework exceptions (overflow, assertion) |
| GEN-05 | P1 | Navigation | App open | Read bottom NavigationBar | Four destinations with labels `MAB`, `Interest`, `Mortgage`, `CPF` in that order |
| GEN-06 | P1 | Navigation | App open | Tap each tab | AppBar titles: `MAB Calculator`, `Interest Calculator`, `Mortgage Calculator`, `CPF Interest Calculator` |
| GEN-07 | P1 | Navigation | Start state | Observe selected tab at launch | MAB is selected |
| GEN-08 | P1 | State | Enter values on Interest (Principal 10000, Rate 5), Mortgage (Loan 500000, Rate 4), CPF (OA 20000) | Switch between all tabs and back | Every tab still shows its typed values and results |
| GEN-09 | P1 | Back | On any tab, no dialog open | Press system Back | App exits to launcher/home without crash; (relaunch works) |
| GEN-10 | P1 | Launcher | Device home | Search launcher / `pm` for the app | Entry named `MoneyKit` exists with an icon (screenshot of launcher/app drawer) |
| GEN-11 | P2 | Banner | App open | Screenshot | No red DEBUG banner |
| GEN-12 | P1 | Persistence | MAB data entered (see MAB-31) | `am force-stop`, relaunch | MAB data restored (see MAB-31) |
| GEN-13 | P2 | Dark mode | `cmd uimode night yes` | Screenshot each of the 4 tabs (with results visible) | Text readable, no white-on-white / black-on-black; cards distinguishable; hero text visible |
| GEN-14 | P2 | Landscape | rotation locked to landscape | Open each tab, scroll | No crash, no overflow stripes, content column centred and scrollable, NavigationBar at bottom |
| GEN-15 | P2 | Large font | `font_scale 1.5` | Open each tab with results | No overflow stripes / clipped hero; everything reachable by scrolling |
| GEN-16 | P2 | Small screen | `wm size 1080x1920` (= 360x640 dp) | Open each tab | No overflow stripes (UI_DESIGN §4). Restore with `wm size reset` |
| GEN-17 | P2 | Keyboard | Focus lower field (e.g. Interest Monthly contribution) | Observe | Focused field scrolls into view above keyboard |
| GEN-18 | P1 | Semantics | Any tab with valid results | Dump UI tree | Hero value appears as content-desc `<label>: <value>` (e.g. `Final balance: $16,470.09`) |

## 2. MAB calculator

| ID | Pri | Area | Preconditions | Steps | Expected |
|---|---|---|---|---|---|
| MAB-01 | P0 | Golden MAB-1 | Fresh | Import CSV: `Account,Date,Balance` / `"Start Amount","1 April, 2025",500.00` / `"Transfer","30 April, 2025",150.00` / `"Food","30 April, 2025",-3.00` | Hero `Monthly Average Balance` = `$504.90`; Lowest `$500.00`; Highest `$647.00`; Days in cycle `30`; Transactions counted `2`; caption `Billing cycle: 1 Apr 2025 – 30 Apr 2025 (30 days)`; snackbar `Imported 2 transactions`; rows `Transfer` / `+$150.00`, `Food` / `-$3.00` |
| MAB-02 | P0 | Golden MAB-2 | Fresh | Import CSV with only the opening row `"Start","15 March, 2025",1000` | `$1,000.00`; Days `31`; caption `Billing cycle: 1 Mar 2025 – 31 Mar 2025 (31 days)`; Lowest/Highest `$1,000.00`; Transactions counted `0` |
| MAB-03 | P0 | Golden MAB-3 (leap year) | Fresh | Import: opening `1 February, 2024` 1000; tx `15 February, 2024` -500 | Days `29`; MAB `$741.38` (741.3793); Lowest `$500.00`; Highest `$1,000.00` |
| MAB-04 | P0 | Golden MAB-4 (ignored tx) | Fresh | Import: opening `1 April, 2025` 100 with name `Start`; tx `Salary`, `5 May, 2025`, 50 | MAB `$100.00`; Transactions counted `0`; warning banner `1 transaction is outside the billing cycle and was ignored: Salary (5 May 2025)` |
| MAB-05 | P0 | Golden MAB-5 (day-1 tx) | Fresh | Import: opening `1 January, 2025` -200; tx `Pay`, `1 January, 2025`, 300 | MAB `$100.00`; Lowest `$100.00`; Highest `$100.00`; Days `31` |
| MAB-06 | P0 | Golden MAB-6 (order-independent) | Fresh | Import opening `1 June, 2025` 1000, then rows in order: `20 June` -100, `10 June` +50, `10 June` -20. Record MAB. Then Reset and import the same rows in the reverse order | Both give MAB `$984.33` (derived: (9x1000 + 10x1030 + 11x930)/30 = 984.333), Lowest `$930.00`, Highest `$1,030.00`, counted `3`; transaction list sorted by date then insertion |
| MAB-07 | P1 | CSV `YYYY-MM-DD` | Fresh | Import: header, opening `2025-04-01` 500, tx `2025-04-30` 150, `2025-04-30` -3 | Same as MAB-01 (`$504.90`) |
| MAB-08 | P1 | Negative opening | Fresh | Import opening `1 January, 2025` -200, no tx | Hero `-$200.00`; Lowest `-$200.00`; Highest `-$200.00` |
| MAB-09 | P1 | Empty state | Fresh | Open MAB tab | Card text `Enter an opening balance to see your Monthly Average Balance.`; Opening balance field shows no error text; `No transactions yet. Add deposits and withdrawals made during the month.` shown |
| MAB-10 | P1 | Default date/cycle | Fresh, typed opening balance 1000 | Read Opening date + caption | Opening date = today (`19 Oct 2026` or the emulator date); caption `Billing cycle: 1 Oct 2026 – 31 Oct 2026 (31 days)`; MAB `$1,000.00` |
| MAB-11 | P1 | Manual opening balance | Fresh | Type `500` into `Opening balance` | Hero `$500.00`, `Opening balance` field has prefix `$` |
| MAB-12 | P1 | Input with commas | Fresh | Type `1,000.50` | Accepted; hero `$1,000.50` |
| MAB-13 | P1 | Invalid opening | Fresh | Type `-` (or `.`) into Opening balance | Field error `Enter a valid amount`; no stale numbers shown (empty-state or `Fix the highlighted fields to see results.`) |
| MAB-14 | P1 | Add deposit | Opening 500 typed | Tap `Add transaction` | Sheet title `Add transaction`; `Deposit` selected by default; fields `Name`, `Date` (default = opening date), `Amount`; buttons `Cancel`, `Save` |
| MAB-15 | P1 | Add deposit save | After MAB-14 | Name `Transfer`, Amount `150`, Save | Row `Transfer`, date, `+$150.00`; Transactions counted `1`; hero changes |
| MAB-16 | P1 | Withdrawal sign | Opening 500 | Add transaction, `Withdrawal`, Name `Food`, Amount `3`, Save | Row shows `-$3.00` (amount typed positive); counted +1 |
| MAB-17 | P1 | Blank name | Opening 500 | Add transaction, leave Name blank, Amount `10`, Save | Row name `Transaction` |
| MAB-18 | P1 | Amount validation | Sheet open | Save with empty Amount; then `0` | Error `Enter a valid amount` each time; sheet stays open; nothing added |
| MAB-19 | P1 | Sheet cancel | Sheet open with data typed | Tap `Cancel` | Sheet closes, no transaction added |
| MAB-20 | P1 | Date outside cycle | Opening 500 at default date, sheet open | Choose a Date in another month via date picker, Save | Error `Date must be within the billing cycle` (or picker prevents it — record which); no transaction added with an outside date |
| MAB-21 | P1 | Edit transaction | At least one transaction | Tap the row | Sheet titled `Edit transaction`, prefilled with name/amount/sign/date; change Amount and Save; row and MAB update |
| MAB-22 | P1 | Delete transaction | At least one transaction | Tap trash (tooltip `Delete transaction`) | Row removed; counted decrements; hero updated; empty message shown when none left |
| MAB-23 | P1 | Transaction ordering | Several txs | Add later-date tx first, then earlier-date | List sorted by date ascending, ties in insertion order |
| MAB-24 | P1 | Ignored banner plural | Fresh | Import opening in Apr 2025 plus two txs in May 2025 | Banner lists both names + dates; wording plural-aware (record exact text; `2 transactions` expected) |
| MAB-25 | P1 | Daily list | After MAB-01 | Find tile `Daily balances (30 days)`; expand | Collapsed by default; after expanding, rows `1 Apr 2025` `$500.00` ... `30 Apr 2025` `$647.00` |
| MAB-26 | P1 | Chart | After MAB-01 | Scroll to chart card | Card titled `Daily balance` is present with a drawn chart |
| MAB-27 | P1 | Import dialog UI | MAB tab | Tap `Import CSV` | Dialog title `Import from CSV`; multiline field label `Paste CSV`; helper with 3-line sample; buttons `Cancel`, `Import` |
| MAB-28 | P1 | Import cancel | Existing data | Open dialog, type junk, `Cancel` | Dialog closes; existing data unchanged |
| MAB-29 | P1 | Import bad rows | Fresh | Import: header, valid opening, then a row with date `abc`, and a row with non-numeric balance | Dialog stays open; errors listed under the field in red (e.g. `Row 3: invalid date 'abc'`); data not silently dropped; no crash |
| MAB-30 | P1 | Import bad opening row | Fresh | Import with an invalid opening row | Error shown, no data imported / existing data unchanged, no crash |
| MAB-31 | P1 | Persistence | Data from MAB-01 loaded | `am force-stop`; relaunch | Opening balance, date, transactions and hero `$504.90` restored |
| MAB-32 | P1 | Reset cancel | Data loaded | Tap `Reset`; dialog `Clear all data?` / `This removes the opening balance and all transactions.`; `Cancel` | Dialog closes; data intact |
| MAB-33 | P1 | Reset clear | Data loaded | `Reset` then `Clear` | Opening balance empty, no transactions, empty-state text shown; after force-stop + relaunch it remains empty |
| MAB-34 | P1 | Import singular | Fresh | Import opening + exactly one tx | Snackbar `Imported 1 transaction` |
| MAB-35 | P1 | Quoted comma | Fresh | Import tx name `"Food, lunch"` | Row name shows `Food, lunch` intact |
| MAB-36 | P1 | Date picker | Opening 500 | Tap `Opening date`, pick a different day in a different month | Field shows the chosen date `d MMM yyyy`; caption updates to that month's first/last day and day count |
| MAB-37 | P1 | Import CRLF/blank line | Fresh | Import golden CSV with a blank line in the middle | Imports without error (blank lines tolerated) |
| MAB-38 | P2 | Large amount | Fresh | Opening `999999999999` | Hero fits on one line (FittedBox), no overflow |
| MAB-39 | P1 | Colour/sign signals | After MAB-01 | Inspect rows | Deposit text starts with `+$`, withdrawal with `-$` (sign not colour only) |
| MAB-40 | P2 | Opening balance zero | Fresh | Type `0` | Hero `$0.00` (valid input, not an error) |

## 3. Interest calculator

Default state: `Compound`, Years `10`, Months `0`, Compounding `Monthly`.

| ID | Pri | Area | Preconditions | Steps | Expected |
|---|---|---|---|---|---|
| INT-01 | P0 | Golden INT-1 | Defaults | Principal `10000`, Rate `5` | Hero `Final balance` = `$16,470.09`; Total interest `$6,470.09`; Total contributions `$0.00`; Initial principal `$10,000.00` |
| INT-02 | P0 | Golden INT-2 | INT-01 inputs | Compounding = `Annually` | `$16,288.95` |
| INT-03 | P0 | Golden INT-3 | INT-01 inputs | Compounding = `Daily` | `$16,486.65` |
| INT-04 | P0 | Golden INT-4 | Principal 10000, Rate 5, 10 y | Select `Simple` | `$15,000.00`; Total interest `$5,000.00` |
| INT-05 | P0 | Golden INT-5 | INT-01 inputs, Compound Monthly | Monthly contribution `200` | `$47,526.55`; Total contributions `$24,000.00`; Total interest `$13,526.55` (derived) |
| INT-06 | P0 | Golden INT-6 | Compound | Principal `5000`, Rate `0`, Years `2`, Contribution `100` | `$7,400.00`; Total interest `$0.00`; contributions `$2,400.00` |
| INT-07 | P0 | Golden INT-7 | Simple | Principal `1000`, Rate `12`, Years `1`, Months `6` | `$1,180.00`; interest `$180.00` |
| INT-08 | P1 | Mode toggle | Compound shown | Select `Simple` | `Compounding` field disappears; select `Compound` again: `Compounding` reappears (value kept) |
| INT-09 | P1 | Compounding options | Compound | Open Compounding dropdown | Options exactly `Annually`, `Semi-annually`, `Quarterly`, `Monthly`, `Daily` |
| INT-10 | P1 | Empty state | Fresh app | Open Interest tab | `Enter a principal and an interest rate to see your results.`; no error text on untouched fields |
| INT-11 | P1 | Rate error | Principal 10000 | Rate `101` | Error `Enter a rate between 0 and 100`; results area shows `Fix the highlighted fields to see results.` |
| INT-12 | P1 | Term error zero | Valid P/R | Years `0`, Months `0` | Error `Enter a term between 1 month and 100 years` + fix hint |
| INT-13 | P1 | Term error max | Valid P/R | Years `101` | Same term error; Years `100` accepted |
| INT-14 | P1 | Principal error | Rate 5 | Principal `.` | `Enter a valid amount`; fix hint |
| INT-15 | P1 | Contribution error | Valid P/R | Contribution `.` | `Enter a valid amount`; fix hint |
| INT-16 | P1 | Defaults | Fresh | Open tab | Years = `10`, Months = `0`, `Compound` selected, Compounding = `Monthly`, field label `Monthly contribution (optional)` |
| INT-17 | P1 | Stats/labels | INT-01 | Read results | Rows `Initial principal`, `Total contributions`, `Total interest`; card `Growth over time` |
| INT-18 | P1 | Year table | INT-01 | Expand `Year by year` | Collapsed by default; header `Year`, `Interest`, `Balance`; 10 rows; last balance `$16,470.09` |
| INT-19 | P1 | Partial year | INT-07 inputs | Expand `Year by year` | Rows `1` and `2*`; footnote `* partial year` |
| INT-20 | P1 | Disclaimer | Any valid | Scroll to bottom | `Estimates only — not financial advice.` |
| INT-21 | P1 | Recovery | After error | Fix rate to `5` | Results return, no stale/blank |
| INT-22 | P2 | Huge values | Principal `999999999999`, Rate `100`, Years `100` | Observe hero | Hero visible on one line, no overflow stripe, no `Infinity`/`NaN` text |
| INT-23 | P2 | Rate boundaries | P=1000 | Rate `0` then `100` | Both accepted (no error) |
| INT-24 | P2 | Months-only term | Valid | Years `0`, Months `1`, rate 12, simple, P 1000 | `$1,010.00` (derived); no error |
| INT-25 | P2 | Year-only blank | Valid | Clear Years field (blank) with Months `6` | No crash; either treated as 0 or term error; record |

## 4. Mortgage calculator

Defaults: `Loan amount` mode, term `25`.

| ID | Pri | Area | Preconditions | Steps | Expected |
|---|---|---|---|---|---|
| MTG-01 | P0 | Golden MTG-1 | Defaults | Loan `500000`, Rate `4` | Hero `Monthly payment` `$2,639.18`; Total interest `$291,755.26` (±$1); Total paid `$791,755.26`; Loan amount `$500,000.00`; Loan term `25 yrs 0 mo`; Payoff date `Oct 2051` (derived, first payment Nov 2026 when today is Oct 2026) |
| MTG-02 | P0 | Golden MTG-2 | MTG-01 | Extra monthly payment `500` | Card `With extra payments`: `Interest saved` `$77,667.69` (±$1), `Time saved` `6 yrs 0 mo`, `New payoff date` `Oct 2045` (derived); Total interest `$214,087.57` (±$1); scheduled monthly payment unchanged at `$2,639.18`; 228 monthly rows |
| MTG-03 | P0 | Golden MTG-3 | Fresh | Loan `120000`, Rate `0`, Term `10` | Payment `$1,000.00`; Total interest `$0.00`; Total paid `$120,000.00` |
| MTG-04 | P0 | Golden MTG-4 | Fresh | Loan `100000`, Rate `3`, Term `1` | Payment `$8,469.37` (derived); monthly schedule has 12 rows; last row Balance `$0.00`; total interest `$1,632.44` (derived) |
| MTG-05 | P1 | Extra hidden | MTG-01 | Clear Extra field / `0` | `With extra payments` card hidden |
| MTG-06 | P1 | Property price mode | Fresh | Select `Property price`; Price `500000`; Down payment `20`; unit `%` (default) | Caption `Loan amount: $400,000.00`; Rate `4` ⇒ payment `$2,111.35` (derived) |
| MTG-07 | P1 | Down payment `$` | Property mode | Unit `$`; Down payment `100000` | Caption `Loan amount: $400,000.00` |
| MTG-08 | P1 | Down payment error | Property mode price 500000 | Down payment `500000` with `$`; and `100` with `%` | Error `Down payment must be less than the price`; fix hint |
| MTG-09 | P1 | Empty state | Fresh app | Open Mortgage | `Enter a loan amount and an interest rate to see your monthly payment.`; no errors on untouched fields |
| MTG-10 | P1 | Rate error | Loan 500000 | Rate `31` | `Enter a rate between 0 and 30`; fix hint (`30` accepted) |
| MTG-11 | P1 | Term error | Loan/rate valid | Term `0`, `41` | `Enter a term between 1 and 40 years` (`40` and `1` accepted) |
| MTG-12 | P1 | Loan error | Rate 4 | Loan `.` | `Enter a valid amount` |
| MTG-13 | P1 | Defaults/labels | Fresh | Read | `Loan amount` mode selected; fields `Loan amount`, `Annual interest rate`, `Loan term (years)` = `25`, `Extra monthly payment (optional)` |
| MTG-14 | P1 | Schedule yearly | MTG-01 | Scroll to `Amortisation schedule` | `Yearly` selected by default; header `Year`, `Principal`, `Interest`, `Balance`; 25 rows; final balance `$0.00` |
| MTG-15 | P1 | Schedule monthly | MTG-01 | Select `Monthly` | Header `#`, `Principal`, `Interest`, `Balance`; first row # 1; scrolling reaches row 300 with Balance `$0.00`; no jank/crash (lazy list) |
| MTG-16 | P1 | Split bar | MTG-01 | Observe | Principal / Interest parts with `$` values and % |
| MTG-17 | P1 | Disclaimer | Valid | Bottom | `Estimates only — not financial advice.` |
| MTG-18 | P2 | Max monthly rows | Loan 500000, Rate 4, Term `40` | Monthly | 480 rows scroll with no crash; last balance `$0.00` |
| MTG-19 | P2 | Large loan | Loan `999999999999`, Rate 30, Term 1 | Observe | Hero fits, no overflow, no `NaN` |
| MTG-20 | P2 | Mode switch keeps values | Fill Loan mode then toggle to Property and back | No crash; Loan amount value preserved (record) |

## 5. CPF interest calculator

Defaults: `Below 55`, Projection years `5`, rates OA 2.5 / SA 4 / MA 4. In each golden case set Projection years `1` unless stated. Hero label: `Total CPF balance after 1 year`.

| ID | Pri | Area | Preconditions | Steps | Expected |
|---|---|---|---|---|---|
| CPF-01 | P0 | Golden CPF-1 | Fresh | OA `20000`, SA `10000`, MA `10000`, years `1` | Total interest earned `$1,700.00`; Basic `$1,300.00` (500+400+400); Extra `$400.00`; hero `$41,700.00`; final OA `$20,500.00`, SA `$10,800.00`, MA `$10,400.00` |
| CPF-02 | P0 | Golden CPF-2 | Fresh | OA/SA/MA each `50000`, years `1` | Total interest `$5,850.00` (basic `$5,250.00`, extra `$600.00`); final SA `$52,600.00`; OA `$51,250.00`; MA `$52,000.00`; hero `$155,850.00` |
| CPF-03 | P0 | Golden CPF-3 | Fresh | `55 & above`; OA `30000`, RA `30000`, MA `10000`, years `1` | Total interest `$3,250.00` (basic `$2,350.00`, extra `$900.00`); OA `$30,750.00`; RA `$32,100.00`; MA `$10,400.00`; hero `$73,250.00` |
| CPF-04 | P0 | Golden CPF-4 | Fresh | Balances blank; expand `Monthly contributions (optional)`; OA contribution `1000`; years `1` | Total interest `$192.50`; Basic `$137.50`; Extra `$55.00`; hero `$12,192.50` (derived); OA `$12,137.50`; SA `$55.00`; MA `$0.00` (derived) |
| CPF-05 | P0 | Golden CPF-5 | CPF-01 inputs | Years `2` | Year 2 interest `$1,772.50` (> 1,700, derived); Total interest earned `$3,472.50`; hero `Total CPF balance after 2 years` `$43,472.50`; OA `$21,012.50`; SA `$11,644.00`; MA `$10,816.00` |
| CPF-06 | P1 | Relabel SA→RA | `Below 55` with SA `10000` typed | Select `55 & above` | Field label `Special Account (SA)` becomes `Retirement Account (RA)` with value `10000` kept; final-balance row also `Retirement Account (RA)`; back to `Below 55` restores `Special Account (SA)` |
| CPF-07 | P1 | Contribution labels | Expand contributions | Toggle bands | `SA contribution` ⇄ `RA contribution`; `OA contribution`, `MA contribution` present |
| CPF-08 | P1 | Defaults | Fresh | Read | `Below 55` selected; `Projection years` = `5`; hero label `Total CPF balance after 5 years`; blank balances ⇒ results shown with `$0.00` (no empty state) |
| CPF-09 | P1 | Singular year | Valid | Years `1` | Hero label exactly `Total CPF balance after 1 year` |
| CPF-10 | P1 | Rates panel | Expand `Interest rates (editable)` | Read | Fields `OA rate` `2.5`, `SA/RA rate` `4`, `MA rate` `4` with `%` suffix; text button `Reset to defaults` |
| CPF-11 | P1 | Rate error | Rates open | `OA rate` `11` | `Enter a rate between 0 and 10`; fix hint; `10` accepted |
| CPF-12 | P1 | Years error | Valid | Years `0`, `41`, blank | `Enter 1 to 40 years` each; `40` and `1` accepted |
| CPF-13 | P1 | Balance error | Valid | OA `.` | `Enter a valid amount` |
| CPF-14 | P1 | Edit rates | CPF-01 inputs | OA rate `5` | Total interest `$2,200.00`; basic `$1,800.00`; extra `$400.00`; hero `$42,200.00` (derived) |
| CPF-15 | P1 | Reset to defaults | After CPF-14 | `Reset to defaults` | Rates back to 2.5/4/4; results back to CPF-01 values |
| CPF-16 | P1 | Year table | CPF-05 | Expand `Year by year` | Collapsed by default; header `Year`, `Interest`, `Total balance`; 2 rows; year 2 interest `$1,772.50`, balance `$43,472.50` |
| CPF-17 | P1 | Disclaimer | Valid | Scroll to bottom | `Estimates only. Interest is calculated monthly on the lowest balance, credited every 31 Dec, and extra interest goes to your SA (below 55) or RA (55 and above). Projection assumes it starts on 1 Jan. Check cpf.gov.sg for current rates.` |
| CPF-18 | P1 | Stats labels | Valid | Read | Rows `Total interest earned`, `Basic interest`, `Extra interest`; final balances `Ordinary Account (OA)`, `Special Account (SA)`, `MediSave Account (MA)` |
| CPF-19 | P2 | Max years | CPF-01, years `40` | Observe | No crash, hero fits, year table has 40 rows |
| CPF-20 | P2 | Large balances | OA `99999999999` etc | Observe | Hero fits, no overflow |
