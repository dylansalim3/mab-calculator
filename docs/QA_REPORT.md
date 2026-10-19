# MoneyKit - QA report (black-box, release APK)

- Build under test: `/Users/dylansalim-ola/Documents/Personal/mab-calculator/dist/moneykit-1.0.0.apk` (package `com.dylansalim.moneykit`, v1.0.0), reinstalled with `adb install -r` on emulator-5554 (Pixel_9_Pro, Android 16, 1280x2856 @480dpi, emulator date 19 Oct 2026).
- Method: black box. Inputs were only `docs/PLAN.md` section 3 and `docs/UI_DESIGN.md`. No source was read. Cases: `/Users/dylansalim-ola/Documents/Personal/mab-calculator/docs/QA_TEST_CASES.md`. Values were read from the uiautomator accessibility tree (text / content-desc / hint); screenshots were used for visual cases.
- Independent oracle: expected values marked "(derived)" in the case file were recomputed with a separate Python implementation of the spec algorithms (CPF year 2, CPF rate edit, 40-year CPF, MTG 1-year loan, 40-year mortgage and so on). Every derived value matched the app.

## Verdict: **SHIP** (after retest on build 9b7a8e06...)

Build 1 verdict was SHIP WITH KNOWN ISSUES (3 P2 failures, 2 defects). After the rebuild (APK sha256 `9b7a8e069056c682d611685193c1ad43a84d2fb47a7ae2811297dc9f6709389f`), DEF-01 and DEF-02 are fixed, all 26 P0 cases re-pass, and there are no open P0, P1 or P2 failures. The original build-1 results are kept below unchanged in the results table, with the retest overrides marked. See the "Retest after fixes" section.

## Summary

Final counts (build 1 results, with INT-22, GEN-15 and GEN-16 overridden by the retest; all 26 P0 re-run on the new build):

| Priority | Total | PASS | FAIL | BLOCKED | N/A |
|---|---|---|---|---|---|
| P0 | 26 | 26 | 0 | 0 | 0 |
| P1 | 80 | 80 | 0 | 0 | 0 |
| P2 | 17 | 17 | 0 | 0 | 0 |
| **All** | **123** | **123** | **0** | **0** | **0** |

Build-1 counts were P0 26/26, P1 80/80, P2 14/17 (3 FAIL: INT-22, GEN-15, GEN-16), total 120/123.

There were no BLOCKED or N/A cases. The suite has 123 cases, more than the 60 to 90 requested, because validation messages and golden vectors were split out individually.

## Defects

| ID | Severity | Case | Summary |
|---|---|---|---|
| DEF-01 | Low | INT-22 | Extreme Interest results are silently wrong and the layout wraps. **FIXED** |
| DEF-02 | Medium (UI) | GEN-15, GEN-16 | Mortgage amortisation table wraps numbers mid-digit at 360 dp width and at 1.5x font. **FIXED** |

### DEF-01 - Interest: huge results clamp to a wrong number (Low, P2 case INT-22) - FIXED in build 9b7a8e06 (verified)
- Repro: Interest tab, Compound, Principal `999999999999`, Annual interest rate `100`, Years `100`, Months `0`, Compounding Monthly.
- Expected: either a correct (astronomical) figure or a clear overflow or limit message. Hero must not show a wrong number.
- Actual: `Final balance: $92,233,720,368,547,760.00` and `Total interest` shows the same figure. This equals 9223372036854775807 / 100, i.e. the value is clamped at the int64 maximum in cents. The true value is about 5e53. Also:
  - the `Total interest` value wraps onto two lines (`$92,233,720,368,547,7` / `60.00`);
  - the left y-axis label of the growth chart is clipped (`,368,547,760.00`).
- No crash. The hero card itself fits on one line.
- Note: a smaller case (MAB opening balance `999999999999`, and Mortgage loan `999999999999` at 30% for 1 year) displayed correctly.
- Screenshot: `/Users/dylansalim-ola/Documents/Personal/mab-calculator/docs/qa-screenshots/INT-22.png`.

### DEF-02 - Mortgage amortisation table wraps numbers mid-digit on narrow screens or large font (Medium, P2 cases GEN-15 and GEN-16) - FIXED in build 9b7a8e06 (verified)
- Repro A (360x640 dp): `adb shell wm size 1080x1920` (density 480), Mortgage tab, Loan `500000`, Rate `4`, Term `25`, scroll to `Amortisation schedule` (Yearly).
- Repro B (1.5x font): `adb shell settings put system font_scale 1.5`, same inputs.
- Expected (UI_DESIGN section 4): no overflow at 360x640 dp or at 1.5x font. Figures stay readable on one line.
- Actual:
  - A: the `Balance` column breaks a number across two lines in every row with a balance of $100,000 or more (`$482,002.2` + `1`, `$463,271.1` + `6`, ...).
  - B: all three money columns break mid-number (`$17,997.7` + `9`, `$18,939.1` + `6`, `$443,776.` + `98`).
  - The other tabs and cards (MAB, Interest, CPF, mortgage summary) wrapped only their labels, not their numbers, and were readable.
- The same wrapping occurs on the Interest year table only for extreme values (see DEF-01). The 427 dp default emulator width is not affected.
- Screenshots: `/Users/dylansalim-ola/Documents/Personal/mab-calculator/docs/qa-screenshots/GEN-16.png` and `/Users/dylansalim-ola/Documents/Personal/mab-calculator/docs/qa-screenshots/GEN-15.png`.

## Observations (unspecified behaviour, not failed)

1. (Changed in build 9b7a8e06, see retest: Summary now shows the accelerated payoff date and term.) Mortgage with an extra payment: the Summary card shows `Total interest $214,087.57` and `Total paid $714,087.57` (with extra) but `Payoff date Oct 2051` and `Loan term 25 yrs 0 mo` (without extra). The accelerated date is only in the `With extra payments` card (`New payoff date Oct 2045`). This is consistent with the spec text but may confuse users.
2. Negative opening balance is displayed in the field as `$-200` (prefix then sign), whereas results use `-$200.00`.
3. Interest tab: leaving `Years` blank with `Months` = 6 gives the term error `Enter a term between 1 month and 100 years` (blank years not treated as 0).
4. MAB Import CSV with an empty field shows the error `No data found` and the dialog stays open. Import success snackbar is plural for 0 (`Imported 0 transactions`).
5. Selecting a transaction date outside the cycle in the sheet shows `Date must be within the billing cycle` immediately after picking it (before Save). The Save was also blocked, as expected.
6. Date picker for the MAB opening date allows any month. Past and future dates are accepted.
7. Landscape: the usable scroll area is small because the app bar and navigation bar take a large share of the height. This is spec-compliant but cramped.
8. UI_DESIGN section 9.2 (unique labels): the MAB card title `Opening balance` and the field label `Opening balance` are the same string. The field is still distinguishable in the accessibility tree because it is an `EditText` whose hint is the label.
9. Interest, Mortgage and CPF state is lost after the app is exited with Back (state is session-only per PLAN A8). This matches the spec.

## Results

Result and observed value for every case, grouped by area. Execution was grouped by screen to limit emulator state changes, so P0 vectors were run first within each area, not globally ahead of all P1 cases.

| ID | Pri | Area | Result | Observed |
|---|---|---|---|---|
| GEN-01 | P0 | Launch | **PASS** | Install -r Success; monkey launch: MAB Calculator shown, no crash dialog; repeated launches/force-stops/relaunch OK |
| GEN-02 | P0 | Packaging | **PASS** | badging: package com.dylansalim.moneykit v1.0.0, application-label 'MoneyKit', adaptive icon res/BW.xml, launchable MainActivity |
| GEN-03 | P0 | Packaging | **PASS** | only uses-permission is com.dylansalim.moneykit.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION; no INTERNET |
| GEN-04 | P0 | Crash log | **PASS** | logcat -d -s AndroidRuntime:E flutter:E and grep FATAL EXCEPTION/ANR/died for the package: no entries (note: logcat ring buffer may not span the whole run; no crash dialog was seen at any point) |
| GEN-05 | P1 | Navigation | **PASS** | Nav labels MAB, Interest, Mortgage, CPF ('Tab n of 4') |
| GEN-06 | P1 | Navigation | **PASS** | AppBar titles: 'MAB Calculator','Interest Calculator','Mortgage Calculator','CPF Interest Calculator' |
| GEN-07 | P1 | Navigation | **PASS** | App launches on MAB tab (title 'MAB Calculator') |
| GEN-08 | P1 | State | **PASS** | Two full tab-cycles: Interest 10000/5/10 -> $16,470.09, Mortgage 500000/4/25 -> $2,639.18, CPF 20000/10000/10000 1y -> $41,700.00 all retained |
| GEN-09 | P1 | Back | **PASS** | System Back on Interest tab: app left to NexusLauncher, no crash dialog, no AndroidRuntime errors; process then relaunchable |
| GEN-10 | P1 | Launcher | **PASS** | App drawer search 'Money' shows icon (teal rounded square with white calculator glyph) labelled 'MoneyKit' (s19.png) |
| GEN-11 | P2 | Banner | **PASS** | No debug banner in any screenshot (s2,s9,s11,s17) |
| GEN-12 | P1 | Persistence | **PASS** | same as MAB-31 |
| GEN-13 | P2 | Dark mode | **PASS** | Dark mode (cmd uimode night yes): all 4 tabs screenshotted top+scrolled (m_dark_1.png, m_dark_2.png): text readable, cards distinguishable from background, hero cards teal with light text, chart visible, bottom nav readable, no white-on-white |
| GEN-14 | P2 | Landscape | **PASS** | Landscape (user_rotation=1): all 4 tabs, 4 scroll positions each (g_land_1.png, g_land_2.png): single centred column, scrolls to the end, no clipped/overflow text, NavigationBar at bottom, no crash (release build draws no overflow stripes; verified visually only). Note: usable viewport is small |
| GEN-15 | P2 | Large font | **PASS (retest)** | Build 1 FAIL; RETEST PASS on 9b7a8e06 (font 1.5): Mortgage yearly table amounts stay on one line (scaled down, still readable); CPF and Interest year tables fine. Build 1: font_scale 1.5: MAB/Interest/CPF fine (labels wrap, nothing clipped). Mortgage 'Amortisation schedule' (Yearly) amount cells break mid-number: e.g. '$17,997.7' + '9', '$482,002.' + '21' -> digits unreadable/ambiguous; spec §4 says no overflow at 1.5x. Screenshot docs/qa-screenshots/GEN-15.png |
| GEN-16 | P2 | Small screen | **PASS (retest)** | Build 1 FAIL; RETEST PASS on 9b7a8e06 (360x640 dp): Mortgage table `$482,002.21` etc. on one line; Interest and CPF year tables fine. Build 1: wm size 1080x1920 @480dpi (=360x640 dp), font 1.0: MAB/Interest/CPF fine. Mortgage yearly Amortisation table: 6-digit Balance values wrap mid-number ('$482,002.2' + '1', '$463,271.1' + '6') in every row with balance >= $100,000. No overflow/clipping elsewhere. Screenshot docs/qa-screenshots/GEN-16.png |
| GEN-17 | P2 | Keyboard | **PASS** | Focusing 'Monthly contribution (optional)' (Interest): field remains visible directly above numeric keyboard (s20.png) |
| GEN-18 | P1 | Semantics | **PASS** | Hero nodes expose content-desc 'Final balance: $16,470.09', 'Monthly Average Balance: $504.90', 'Monthly payment: $2,639.18', 'Total CPF balance after 1 year: $41,700.00' |
| MAB-01 | P0 | Golden MAB-1 | **PASS** | Hero 'Monthly Average Balance: $504.90'; Lowest $500.00; Highest $647.00; Days 30; Transactions counted 2; caption 'Billing cycle: 1 Apr 2025 – 30 Apr 2025 (30 days)'; snackbar 'Imported 2 transactions'; rows 'Transfer 30 Apr 2025 +$150.00', 'Food 30 Apr 2025 -$3.00' |
| MAB-02 | P0 | Golden MAB-2 | **PASS** | Hero $1,000.00; Days 31; caption 'Billing cycle: 1 Mar 2025 – 31 Mar 2025 (31 days)'; Low/High $1,000.00; counted 0; Opening date '15 Mar 2025'; snackbar 'Imported 0 transactions' |
| MAB-03 | P0 | Golden MAB-3 (leap year) | **PASS** | Days 29; caption '1 Feb 2024 – 29 Feb 2024 (29 days)'; MAB $741.38; Low $500.00; High $1,000.00; counted 1 |
| MAB-04 | P0 | Golden MAB-4 (ignored tx) | **PASS** | MAB $100.00; counted 0; banner '1 transaction is outside the billing cycle and was ignored: Salary (5 May 2025)' |
| MAB-05 | P0 | Golden MAB-5 (day-1 tx) | **PASS** | MAB $100.00; Low/High $100.00; Days 31; counted 1; opening field shows -200 |
| MAB-06 | P0 | Golden MAB-6 (order-independent) | **PASS** | Both input orders: MAB $984.33, Low $930.00, High $1,030.00, counted 3; same-day txs listed in insertion order (B,C / C,B) |
| MAB-07 | P1 | CSV `YYYY-MM-DD` | **PASS** | YYYY-MM-DD dates: MAB $504.90, counted 2, same as MAB-01 |
| MAB-08 | P1 | Negative opening | **PASS** | Hero 'Monthly Average Balance: -$200.00'; Low/High -$200.00; Days 31 |
| MAB-09 | P1 | Empty state | **PASS** | Empty-state 'Enter an opening balance to see your Monthly Average Balance.' + 'No transactions yet. Add deposits and withdrawals made during the month.'; no error on untouched field |
| MAB-10 | P1 | Default date/cycle | **PASS** | After Reset: Opening date '19 Oct 2026' (emulator date), caption 'Billing cycle: 1 Oct 2026 – 31 Oct 2026 (31 days)'; typed 1000 -> $1,000.00 |
| MAB-11 | P1 | Manual opening balance | **PASS** | typed 500 -> hero desc 'Monthly Average Balance: $500.00'; '$' prefix present; summary 500/500/31/0 |
| MAB-12 | P1 | Input with commas | **PASS** | '1,000.50' accepted, field keeps text, hero $1,000.50 |
| MAB-13 | P1 | Invalid opening | **PASS** | '-' and '.' -> 'Enter a valid amount' under field + 'Fix the highlighted fields to see results.' |
| MAB-14 | P1 | Add deposit | **PASS** | Sheet 'Add transaction': Deposit selected (checkmark) / Withdrawal, fields Name, Date '1 Apr 2025' (= opening date), Amount, buttons Cancel/Save |
| MAB-15 | P1 | Add deposit save | **PASS** | Deposit 'Transfer' 150 at default date 19 Oct 2026: row '+$150.00', MAB $1,062.90 (=(18*1000+13*1150)/31), counted 1, Highest $1,150.00 |
| MAB-16 | P1 | Withdrawal sign | **PASS** | Withdrawal 25 shows row 'Transaction 1 Apr 2025 -$25.00'; MAB $479.90 (=(475*29+622)/30) |
| MAB-17 | P1 | Blank name | **PASS** | Blank Name -> row name 'Transaction' |
| MAB-18 | P1 | Amount validation | **PASS** | Empty Amount and Amount 0 both -> 'Enter a valid amount' under field; sheet stays open |
| MAB-19 | P1 | Sheet cancel | **PASS** | Typed Name/Amount then Cancel: no row added, MAB unchanged |
| MAB-20 | P1 | Date outside cycle | **PASS** | Tx sheet date picker allows other months; picking 5 May 2025 (cycle Apr) shows 'Date must be within the billing cycle' under Date; Save with Amount 10 kept sheet open, nothing added (list still 2 txs) |
| MAB-21 | P1 | Edit transaction | **PASS** | Row tap opens 'Edit transaction' prefilled (Name Transaction, Date 1 Apr 2025, Amount 25, Withdrawal selected); Amount->100 Save: row '-$100.00', MAB $404.90, Lowest $400.00, Highest $547.00 |
| MAB-22 | P1 | Delete transaction | **PASS** | Delete tx: counted 3->... each tap removed one row, MAB $504.90 -> $499.90 -> $500.00; empty message shown when none left |
| MAB-23 | P1 | Transaction ordering | **PASS** | Tx added last with date 1 Apr appears first, before the 30 Apr rows (date-sorted) |
| MAB-24 | P1 | Ignored banner plural | **PASS** | Banner '2 transactions are outside the billing cycle and were ignored: Salary (5 May 2025), Bonus (10 Jun 2025)'; counted 0; MAB $100.00 |
| MAB-25 | P1 | Daily list | **PASS** | Collapsed by default ('Daily balances (30 days)'); expanded rows '1 Apr 2025 $500.00' ... '30 Apr 2025 $647.00' (30 rows) |
| MAB-26 | P1 | Chart | **PASS** | Card 'Daily balance' with stepped chart (screenshot s2.png), semantics 'Chart from $500.00 to $647.00, low $500.00, high $647.00' |
| MAB-27 | P1 | Import dialog UI | **PASS** | Dialog 'Import from CSV', field hint 'Paste CSV', sample 3 lines, buttons Cancel/Import |
| MAB-28 | P1 | Import cancel | **PASS** | typed junk, Cancel: dialog closed, opening balance 500 / hero $500.00 unchanged |
| MAB-29 | P1 | Import bad rows | **PASS** | Dialog stayed open; red errors "Row 3: invalid date 'abc'" and "Row 4: invalid amount 'xyz'" under field (screenshot s5.png); Cancel -> existing data (-200) unchanged |
| MAB-30 | P1 | Import bad opening row | **PASS** | Bad opening row: dialog stays open with "Row 2: invalid date 'notadate'"; Cancel -> previous data (-200) intact; no crash |
| MAB-31 | P1 | Persistence | **PASS** | force-stop + relaunch: opening 500, 1 Apr 2025, 2 txs, hero $504.90 restored |
| MAB-32 | P1 | Reset cancel | **PASS** | 'Clear all data?' / 'This removes the opening balance and all transactions.' Cancel kept 500 and hero $500.00 |
| MAB-33 | P1 | Reset clear | **PASS** | Clear -> empty state; after force-stop+relaunch still empty (opening empty, no txs, empty-state card) |
| MAB-34 | P1 | Import singular | **PASS** | Snackbar 'Imported 1 transaction' (singular) seen in MAB-03/04/05; 'Imported 3 transactions' / 0 transactions plural ok |
| MAB-35 | P1 | Quoted comma | **PASS** | Name 'Food, lunch' preserved; row 'Food, lunch 3 Apr 2025 -$12.50'; MAB $488.33 |
| MAB-36 | P1 | Date picker | **PASS** | Opening date picker -> 15 May 2025: field '15 May 2025', caption '1 May 2025 – 31 May 2025 (31 days)', Bonus(Jun) ignored, MAB $143.55 (=(4*100+27*150)/31) |
| MAB-37 | P1 | Import CRLF/blank line | **PASS** | Blank lines tolerated; imported 2 transactions; MAB $504.90 |
| MAB-38 | P2 | Large amount | **PASS** | 999999999999 -> hero '$999,999,999,999.00' fits on one line (screenshot s8.png) |
| MAB-39 | P1 | Colour/sign signals | **PASS** | Rows read '+$150.00' and '-$3.00' |
| MAB-40 | P2 | Opening balance zero | **PASS** | 0 -> hero $0.00, no error |
| INT-01 | P0 | Golden INT-1 | **PASS** | Final balance: $16,470.09; Initial principal $10,000.00; Total contributions $0.00; Total interest $6,470.09; split 60.7%/39.3% |
| INT-02 | P0 | Golden INT-2 | **PASS** | Annually: Final balance $16,288.95; interest $6,288.95 |
| INT-03 | P0 | Golden INT-3 | **PASS** | Daily: Final balance $16,486.65; interest $6,486.65 |
| INT-04 | P0 | Golden INT-4 | **PASS** | Simple: Final balance $15,000.00; Total interest $5,000.00; Compounding field hidden |
| INT-05 | P0 | Golden INT-5 | **PASS** | Final balance $47,526.55; contributions $24,000.00; interest $13,526.55; split 21.0/50.5/28.5% |
| INT-06 | P0 | Golden INT-6 | **PASS** | Final $7,400.00; interest $0.00; contributions $2,400.00; interest part omitted from split |
| INT-07 | P0 | Golden INT-7 | **PASS** | Simple 1y6m: Final $1,180.00; interest $180.00 |
| INT-08 | P1 | Mode toggle | **PASS** | Simple hides Compounding; Compound restores it with previous value ('Compounding Daily') |
| INT-09 | P1 | Compounding options | **PASS** | Dropdown options exactly: Annually, Semi-annually, Quarterly, Monthly, Daily |
| INT-10 | P1 | Empty state | **PASS** | Fresh Interest tab: 'Enter a principal and an interest rate to see your results.'; no error text on untouched fields |
| INT-11 | P1 | Rate error | **PASS** | Rate 101 -> 'Enter a rate between 0 and 100' + 'Fix the highlighted fields to see results.' |
| INT-12 | P1 | Term error zero | **PASS** | Years 0/Months 0 -> 'Enter a term between 1 month and 100 years' + fix hint |
| INT-13 | P1 | Term error max | **PASS** | Years 101 -> term error; Years 100 accepted (Final $1,468,794.49) |
| INT-14 | P1 | Principal error | **PASS** | Principal '.' -> 'Enter a valid amount' + fix hint |
| INT-15 | P1 | Contribution error | **PASS** | Contribution '.' -> 'Enter a valid amount' + fix hint |
| INT-16 | P1 | Defaults | **PASS** | Defaults: Years 10, Months 0, Compound selected (screenshot s9.png), Compounding 'Monthly', 'Monthly contribution (optional)' |
| INT-17 | P1 | Stats/labels | **PASS** | Summary rows 'Initial principal','Total contributions','Total interest'; card 'Growth over time' with chart semantics |
| INT-18 | P1 | Year table | **PASS** | Year by year collapsed by default; expanded header 'Year','Interest','Balance'; 10 rows; year1 $511.62/$10,511.62 ... year10 $801.63/$16,470.09 |
| INT-19 | P1 | Partial year | **PASS** | 1y6m simple table: rows '1' $120.00/$1,120.00 and '2*' $60.00/$1,180.00; tile text includes '* partial year' |
| INT-20 | P1 | Disclaimer | **PASS** | Footer 'Estimates only — not financial advice.' at bottom |
| INT-21 | P1 | Recovery | **PASS** | After fixing, hero back to $16,470.09 |
| INT-22 | P2 | Huge values | **PASS (retest)** | Build 1 FAIL; RETEST PASS on 9b7a8e06: hero and Total interest show `$5.18e+53` (matches independent calc 5.182e53), no wrapping in Summary or the year table. Residual cosmetic: chart low y-label `$999,999,999,999.00` is clipped at the left edge. Build 1: P=999999999999, 100%, 100y: hero 'Final balance: $92,233,720,368,547,760.00' and Total interest same value -> value is clamped to int64-max-cents (9223372036854775807/100); true value ~5e53, so displayed number is silently wrong. 'Total interest' value wraps onto 2 lines ('$92,233,720,368,547,7' / '60.00'); chart y-label clipped at left edge. No crash, hero itself did not overflow. Screenshot docs/qa-screenshots/INT-22.png |
| INT-23 | P2 | Rate boundaries | **PASS** | Rate 100 accepted ($148,406,441.31), rate 0 accepted ($10,000.00) |
| INT-24 | P2 | Months-only term | **PASS** | Years 0 + Months 1 (compound monthly 5%%, P 10000): no error, Final balance $10,041.67 (=10000*(1+0.05/12)) |
| INT-25 | P2 | Year-only blank | **PASS** | Years blank + Months 6: shows term error 'Enter a term between 1 month and 100 years' (blank Years not treated as 0) - no crash; unspecified |
| MTG-01 | P0 | Golden MTG-1 | **PASS** | Monthly payment: $2,639.18; Loan amount $500,000.00; Total interest $291,755.26; Total paid $791,755.26; Payoff date Oct 2051; Loan term 25 yrs 0 mo |
| MTG-02 | P0 | Golden MTG-2 | **PASS (retest)** | RETEST PASS on 9b7a8e06: Summary Total interest $214,087.57, Payoff date Oct 2045, Loan term 19 yrs 0 mo; With extra payments card: Interest saved $77,667.69, Time saved 6 yrs 0 mo, New payoff date Oct 2045. Build 1 had the accelerated plan only in the extra card. Build 1: Extra 500: 'With extra payments' card: Interest saved $77,667.69; Time saved 6 yrs 0 mo; New payoff date Oct 2045; Total interest $214,087.57; Total paid $714,087.57; scheduled Monthly payment unchanged $2,639.18; yearly table 19 rows (last year 19 ends $0.00). Note: summary 'Payoff date' still Oct 2051 / 'Loan term' 25 yrs 0 mo (baseline) |
| MTG-03 | P0 | Golden MTG-3 | **PASS** | L 120000, 0%, 10y: Monthly payment $1,000.00; Total interest $0.00; Total paid $120,000.00; Payoff Oct 2036; 10 yrs 0 mo |
| MTG-04 | P0 | Golden MTG-4 | **PASS** | L 100000, 3%, 1y: payment $8,469.37; total interest $1,632.44; monthly rows 1..12, row 1 $8,219.37/$250.00/$91,780.63, row 12 balance $0.00; yearly single row 1 $100,000.00/$1,632.44/$0.00 |
| MTG-05 | P1 | Extra hidden | **PASS** | Extra cleared -> 'With extra payments' card disappears; Total interest back to $291,755.26 |
| MTG-06 | P1 | Property price mode | **PASS** | Property price 500000 + Down 20 (%): caption 'Loan amount: $400,000.00'; payment $2,111.35; interest $233,404.21 |
| MTG-07 | P1 | Down payment `$` | **PASS** | Unit $ with Down 100000: caption 'Loan amount: $400,000.00', payment $2,111.35 |
| MTG-08 | P1 | Down payment error | **PASS** | $ mode: Down 500000 on price 500000 -> 'Down payment must be less than the price' + fix hint; Down 499999 -> 'Loan amount: $1.00'; % mode: 100 -> same error; % 0 -> loan $500,000.00 |
| MTG-09 | P1 | Empty state | **PASS** | Fresh: 'Enter a loan amount and an interest rate to see your monthly payment.'; no field errors |
| MTG-10 | P1 | Rate error | **PASS** | Rate 31 -> 'Enter a rate between 0 and 30' + fix hint; 30 accepted (payment $11,698.46 for 120k/1y) |
| MTG-11 | P1 | Term error | **PASS** | Term 0 and 41 -> 'Enter a term between 1 and 40 years' + fix hint; 40 and 1 accepted with no error |
| MTG-12 | P1 | Loan error | **PASS** | Loan '.' -> 'Enter a valid amount' + fix hint |
| MTG-13 | P1 | Defaults/labels | **PASS** | Loan amount segment default, fields 'Loan amount','Annual interest rate','Loan term (years)'=25,'Extra monthly payment (optional)' |
| MTG-14 | P1 | Schedule yearly | **PASS** | 'Amortisation schedule' header Year/Principal/Interest/Balance, Yearly default, 25 rows, row 1 $11,886.56/$19,783.65/$488,113.44, row 25 balance $0.00 |
| MTG-15 | P1 | Schedule monthly | **PASS** | Monthly toggle: header '#','Principal','Interest','Balance'; row 1 $1,472.52/$1,666.67/$498,527.48 ... row 228 $1,487.80/$4.96/$0.00 (with extra 500); lazy list scrolled with fling without crash |
| MTG-16 | P1 | Split bar | **PASS** | Split bar legend 'Principal $500,000.00 (63.2%)' / 'Interest $291,755.26 (36.8%)' |
| MTG-17 | P1 | Disclaimer | **PASS** | Footer 'Estimates only — not financial advice.' |
| MTG-18 | P2 | Max monthly rows | **PASS** | 40y 500000@4%: payment $2,089.69, interest $503,052.33, monthly list reaches row 480 balance $0.00 without crash |
| MTG-19 | P2 | Large loan | **PASS** | Loan 999999999999, 30%, 1y: hero '$97,487,126,988.24' fits, no NaN/overflow stripes; cosmetic only: yearly-table amount cells wrap onto 2 lines (screenshot s16.png) |
| MTG-20 | P2 | Mode switch keeps values | **PASS** | Loan<->Property toggle: Loan amount field value 500000 preserved; property mode without price shows empty state |
| CPF-01 | P0 | Golden CPF-1 | **PASS** | 1y: hero 'Total CPF balance after 1 year: $41,700.00'; Total interest $1,700.00; Basic $1,300.00; Extra $400.00; OA $20,500.00; SA $10,800.00; MA $10,400.00 |
| CPF-02 | P0 | Golden CPF-2 | **PASS** | 50k/50k/50k 1y: interest $5,850.00 (basic $5,250.00, extra $600.00); OA $51,250.00; SA $52,600.00; MA $52,000.00; hero $155,850.00 |
| CPF-03 | P0 | Golden CPF-3 | **PASS** | 55+, OA 30000, RA 30000, MA 10000, 1y: Total interest $3,250.00; Basic $2,350.00; Extra $900.00; OA $30,750.00; RA $32,100.00; MA $10,400.00; hero $73,250.00 |
| CPF-04 | P0 | Golden CPF-4 | **PASS** | Contribution OA 1000/mo, blank balances, 1y: interest $192.50 (basic $137.50, extra $55.00); hero $12,192.50; OA $12,137.50; SA $55.00; MA $0.00 |
| CPF-05 | P0 | Golden CPF-5 | **PASS** | 2y of CPF-1 inputs: hero 'after 2 years' $43,472.50; Total interest $3,472.50 (basic $2,660.50, extra $812.00); OA $21,012.50; SA $11,644.00; MA $10,816.00; table year2 interest $1,772.50 > $1,700 |
| CPF-06 | P1 | Relabel SA→RA | **PASS** | Switch to '55 & above': field 'Special Account (SA)' -> 'Retirement Account (RA)' with typed value kept (50000 then 30000); final balances row 'Retirement Account (RA)'; back to 'Below 55' restores 'Special Account (SA)' with value |
| CPF-07 | P1 | Contribution labels | **PASS** | 55+: contributions fields 'OA contribution','RA contribution','MA contribution' |
| CPF-08 | P1 | Defaults | **PASS** | Fresh: 'Below 55' default, Projection years 5, hero 'Total CPF balance after 5 years: $0.00' (blank balances valid, no empty state) |
| CPF-09 | P1 | Singular year | **PASS** | Years 1 -> 'Total CPF balance after 1 year' (singular) |
| CPF-10 | P1 | Rates panel | **PASS** | Rates panel: OA rate 2.5, SA/RA rate 4, MA rate 4, button 'Reset to defaults' (% suffix per screenshot-less tree) |
| CPF-11 | P1 | Rate error | **PASS** | OA rate 11 -> 'Enter a rate between 0 and 10' + 'Fix the highlighted fields to see results.'; 10 accepted |
| CPF-12 | P1 | Years error | **PASS** | Years 0, 41, blank -> 'Enter 1 to 40 years' + fix hint; 40 and 1 accepted |
| CPF-13 | P1 | Balance error | **PASS** | OA '.' -> 'Enter a valid amount' + fix hint |
| CPF-14 | P1 | Edit rates | **PASS** | OA rate 5, 2y: Total interest $4,510.00 (basic $3,698.00, extra $812.00), hero $44,510.00 = independent calc (1y would be $2,200/$42,200) |
| CPF-15 | P1 | Reset to defaults | **PASS** | 'Reset to defaults' restores 2.5/4/4; 1y results back to $41,700.00 / $1,700.00 |
| CPF-16 | P1 | Year table | **PASS** | 'Year by year' collapsed by default; header Year/Interest/Total balance; rows '1 $1,700.00 $41,700.00', '2 $1,772.50 $43,472.50' |
| CPF-17 | P1 | Disclaimer | **PASS** | Disclaimer text exactly matches spec |
| CPF-18 | P1 | Stats labels | **PASS** | Summary rows Total interest earned/Basic interest/Extra interest; 'Final balances' Ordinary Account (OA)/Special Account (SA)/MediSave Account (MA) |
| CPF-19 | P2 | Max years | **PASS** | 40y of CPF-1 inputs: hero $200,906.85, interest $160,906.85 = independent calc; no crash (year-table rows not counted) |
| CPF-20 | P2 | Large balances | **PASS** | Balances 99999999999 x3, 40y: hero 'Total CPF balance after 40 years: $1,228,711,384,527.84' fits one line, no overflow (s18.png); numbers plausible |

## Retest after fixes (build 9b7a8e06...)

Build: `/Users/dylansalim-ola/Documents/Personal/mab-calculator/dist/moneykit-1.0.0.apk`, sha256 `9b7a8e069056c682d611685193c1ad43a84d2fb47a7ae2811297dc9f6709389f`, reinstalled with `adb -s emulator-5554 install -r` (Success; package, label `MoneyKit` and the absence of INTERNET unchanged). Same black-box rules.

| Item | Result | Observed |
|---|---|---|
| DEF-01 / INT-22 | **FIXED** | P=999999999999, 100%, 100 y: `Final balance: $5.18e+53`, Total interest `$5.18e+53`, split legend `$5.18e+53 (100.0%)`, chart label `$5.18e+53`. Independent value 1e12 x (1+1/12)^1200 = 5.182e53. Year table amounts shrink to fit on one line. Residual cosmetic only: chart low y-label `$999,999,999,999.00` is cut off at the left edge. Screenshot `/Users/dylansalim-ola/Documents/Personal/mab-calculator/docs/qa-screenshots/retest-INT-22.png`. |
| DEF-02 / GEN-16 (360x640 dp) | **FIXED** | Mortgage yearly table: `$482,002.21`, `$283,172.08`, `$104,866.03` all on one line in every row. Interest and CPF year tables also fine. Screenshots `.../qa-screenshots/retest-GEN-16-mortgage-360dp.png`, `.../qa-screenshots/retest-year-tables-360dp.png`. |
| DEF-02 / GEN-15 (font 1.5) | **FIXED** | Mortgage table numbers scale down (smaller but whole and readable), no mid-number wrap. Screenshot `.../qa-screenshots/retest-GEN-15-mortgage-1.5x.png`. |
| MTG-02 (extra payment) | PASS | 500000 / 4% / 25y / extra 500: Summary Total interest `$214,087.57`, Total paid `$714,087.57`, `Payoff date Oct 2045`, `Loan term 19 yrs 0 mo`. `With extra payments`: Interest saved `$77,667.69`, Time saved `6 yrs 0 mo`, New payoff date `Oct 2045` (equals the Summary Payoff date). Clearing the extra payment hides the card and restores `Oct 2051` / `25 yrs 0 mo`. |

P0 smoke on the new build (all 26 re-run):

| Case | Result | Observed |
|---|---|---|
| GEN-01 | PASS | Reinstall and launch OK on the MAB tab, no crash dialog. |
| GEN-02 | PASS | Package `com.dylansalim.moneykit` 1.0.0, label `MoneyKit`. |
| GEN-03 | PASS | Only permission is `...DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; no INTERNET. |
| GEN-04 | PASS | No AndroidRuntime/flutter errors, no FATAL EXCEPTION or ANR in logcat after the retest. |
| MAB-01 | PASS | `$504.90`, low `$500.00`, high `$647.00`, 30 days, 2 counted. |
| MAB-02 | PASS | `$1,000.00`, 31 days. |
| MAB-03 | PASS | `$741.38`, 29 days, low `$500.00`, high `$1,000.00`. |
| MAB-04 | PASS | `$100.00`, counted 0, banner `1 transaction is outside the billing cycle and was ignored: Salary (5 May 2025)`. |
| MAB-05 | PASS | `$100.00`, 31 days. |
| MAB-06 | PASS | Both input orders `$984.33`, low `$930.00`, high `$1,030.00`. |
| INT-01 | PASS | `$16,470.09`. |
| INT-02 | PASS | `$16,288.95`. |
| INT-03 | PASS | `$16,486.65`. |
| INT-04 | PASS | `$15,000.00`, Compounding hidden. |
| INT-05 | PASS | `$47,526.55`, contributions `$24,000.00`, interest `$13,526.55`. |
| INT-06 | PASS | `$7,400.00`. |
| INT-07 | PASS | `$1,180.00`. |
| MTG-01 | PASS | `$2,639.18`, interest `$291,755.26`, paid `$791,755.26`, Oct 2051, 25 yrs 0 mo. |
| MTG-02 | PASS | See above. |
| MTG-03 | PASS | `$1,000.00`, interest `$0.00`, paid `$120,000.00`. |
| MTG-04 | PASS | `$8,469.37`, interest `$1,632.44`, yearly row balance `$0.00`, monthly rows 9-11 as before. |
| CPF-01 | PASS | Hero `$41,700.00`; interest `$1,700.00` (basic `$1,300.00`, extra `$400.00`); OA `$20,500.00`, SA `$10,800.00`, MA `$10,400.00`. |
| CPF-02 | PASS | Interest `$5,850.00`; SA `$52,600.00`. |
| CPF-03 | PASS | Interest `$3,250.00`; OA `$30,750.00`, RA `$32,100.00`, MA `$10,400.00`. |
| CPF-04 | PASS | Interest `$192.50` (basic `$137.50`, extra `$55.00`), hero `$12,192.50`. |
| CPF-05 | PASS | 2 y: interest `$3,472.50`, year 2 `$1,772.50`, hero `$43,472.50`. |

MTG-04 monthly row 12 was not re-scrolled in the retest (rows 1-11 were; the yearly row ends at `$0.00` and matched build 1). Only P0 cases, the three failed cases and MTG-02 were re-run. P1 and the remaining P2 cases were not re-run on the new build, so the build-1 results stand for those (the rebuild touched only number formatting, the year tables and the mortgage summary). Device settings were reset after the retest: font scale 1.0, `wm size` and `wm density` reset, night mode auto, rotation portrait/auto.

## Not tested / limitations

- Corrupt persisted data ("Corrupt data -> start empty, no crash"): not testable black-box on a non-debuggable release build without touching the app data directory.
- Release builds do not draw Flutter overflow stripes and Flutter errors are not logged in release. Overflow and clipping checks (GEN-14, GEN-15, GEN-16) were therefore judged visually from screenshots. Only sampled scroll positions were viewed, not every pixel of every screen.
- Logcat is a ring buffer. The final `AndroidRuntime:E flutter:E` check showed no entries, but it may not cover the whole session. No crash dialog or process death was observed at any time.
- TalkBack was not run. Accessibility was judged only from the uiautomator tree (labels, content-desc, tooltips as names). Touch target sizes (48 dp) and WCAG contrast were not measured. Dark mode readability was judged visually.
- Reduced-motion behaviour, `AnimatedSwitcher` timing and SnackBar 4 s minimum duration were not measured.
- The default MAB `Opening date` and the default mortgage `start month` depend on the emulator date (Oct 2026). Mortgage payoff dates were checked for that date only.
- Only one device profile (Pixel 9 Pro, Android 16) was used. Small-screen coverage is a `wm size` emulation, not a real device.
- Release signing was not verified here (`apksigner verify` is outside the black-box scope).
- Mortgage and CPF year-table row counts: only spot checked (first, last and a few middle rows). CPF 40-year table row count not counted.
- Device settings were reset at the end: font scale 1.0, accelerometer rotation on / user rotation 0, night mode auto, `wm size` and `wm density` reset. User apps `com.ninspend.mobile` and `com.hisong.android` were not touched; the debug APK was not installed.
