# MoneyKit — UI / UX Design

Material 3 (`useMaterial3: true`), Flutter, Android. Companion to [`PLAN.md`](PLAN.md).
**Exact visible strings in this document are part of the contract**: widget tests and the black-box QA agent locate controls by these labels. Do not reword them.

---

## 1. Design principles

1. **Answer first.** Every screen shows the headline number (the "hero") as soon as inputs are valid. No "Calculate" button — results update live as the user types.
2. **Forms that respect thumbs.** Inputs top-down in one column, numeric keyboards, 48 dp minimum touch targets, primary actions in the lower half.
3. **Quiet, trustworthy finance look.** Teal seed colour, generous whitespace, tabular figures for numbers so digits don't jitter.
4. **Never silently wrong.** Invalid input → inline error text on that field and the results area shows a hint instead of stale numbers.
5. **Works offline, instantly.** No spinners, no network, no permissions.

## 2. Design tokens

| Token | Value |
|---|---|
| Seed colour | `Color(0xFF006A60)` (teal) → `ColorScheme.fromSeed`, both `Brightness.light` and `dark`; follow system |
| Positive amount | `colorScheme.primary` · Negative amount: `colorScheme.error` |
| Typography | M3 default (Roboto). Hero value: `displaySmall`, weight 600. All numbers use `FontFeature.tabularFigures()` |
| Spacing scale | 4 · 8 · 12 · 16 · 24 · 32 dp. Screen gutter 16 dp. Gap between cards 12 dp. Gap between fields 12 dp |
| Shape | Cards radius 16 · text fields radius 12 · buttons: M3 stadium · bottom sheet top radius 28 |
| Card style | `Card.filled`-like: `surfaceContainerLow`, no elevation, no border |
| Max content width | 640 dp, centred (landscape / tablets) |
| Motion | M3 defaults; `AnimatedSwitcher` 200 ms on hero value; respect reduced-motion (`MediaQuery.disableAnimations`) |
| Icon | Adaptive launcher icon: teal background, white calculator-with-coin glyph (generated once, vector) |

## 3. Navigation & shell

Single `Scaffold` with a Material 3 **`NavigationBar`** (4 destinations — each ≥ 80 dp wide at 320 dp; design-reviewed for small phones), body is an `IndexedStack` so each calculator keeps its inputs while switching tabs.

```
┌──────────────────────────────┐
│  <screen AppBar>             │
│                              │
│        <screen body>         │
│                              │
├──────────────────────────────┤
│ ◉MAB  ◯Interest  ◯Mortgage  ◯CPF  ◯Settings │   NavigationBar
└──────────────────────────────┘
```

| Order | Label (exact) | Icon (outlined / filled when selected) | AppBar title (exact) |
|---|---|---|---|
| 1 | `MAB` | `account_balance_wallet` | `MAB Calculator` |
| 2 | `Tools` (tooltip `Interest, Mortgage and CPF calculators`) | `calculate` | follows the segment: `Interest Calculator` / `Mortgage Calculator` / `CPF Interest Calculator` |
| 3 | `Split` | `group` | `Bill Split` |
| 4 | `Settings` | `settings` | `Settings` |

**Tools tab:** the AppBar carries a 3-segment `SegmentedButton` (`Interest` ‹default›, `Mortgage`, `CPF`) in its bottom slot. The three screens live in a nested `IndexedStack`, so each keeps its inputs while you switch; the AppBar title changes with the segment. The switcher's text scale is clamped to 1.2× so the three labels stay on one line on a 320 dp phone. Bottom-bar text scale is clamped to 1.3× so labels never wrap mid-word; segment labels also scale down to fit. (Rationale: six bottom tabs gave ~53 dp slots at 320 dp and clipped "Mortgage"; the three calculators are used one at a time, so they share one tab; the label is `Tools` because `Calculators` (≈ 68 dp) wrapped at 320 dp with large fonts. An XE-style "More" tab was rejected because Settings must stay the last tab.)

Start tab: MAB. Back button on any tab exits the app (no back-stack between tabs).

## 4. Responsive rules

- Content column `ConstrainedBox(maxWidth: 640)` + `Center`; `ListView` with 16 dp padding and `keyboardDismissBehavior: onDrag`.
- Landscape: same single column (scrolls); `NavigationBar` stays at the bottom. No overflow errors at 360×640 dp or at 1.5× font scale.
- Keyboard: `resizeToAvoidBottomInset: true`; the focused field scrolls into view; `TextInputAction.next` between fields, `done` on the last.

## 5. States, validation & copy

| Situation | Behaviour |
|---|---|
| Required input empty | Results area shows an **empty-state card**: icon + text from the screen spec. No error on untouched fields. |
| Invalid value (after the field was edited) | `errorText` under the field (exact strings per screen) + results area shows `Fix the highlighted fields to see results.` |
| Number input | Accept digits, one `.`, and thousands commas (`1,000.50`). Negative sign only where stated. Parsed by `parseNum`. |
| Large results | Money is formatted `$1,234,567.89`; negatives `-$1,234.56`. Hero value uses `FittedBox(scaleDown)` so it never overflows. |
| Disclaimer | Footer text on Interest/Mortgage/CPF: `Estimates only — not financial advice.` (CPF has a longer one) |

## 6. Shared component kit (`lib/core/widgets/`, owned by the coordinator)

| Widget | API | Notes |
|---|---|---|
| `NumberField` | `NumberField({required label, required controller, prefixText, suffixText, helperText, errorText, allowNegative = false, onChanged, textInputAction})` | Outlined, `TextInputType.numberWithOptions(decimal: true, signed: allowNegative)`; input formatter allows digits/`.`/`,`/optional leading `-` |
| `DateField` | `DateField({required label, required DateTime? value, required ValueChanged<DateTime> onChanged, errorText, firstDate, lastDate})` | Read-only outlined field with calendar icon; tap opens `showDatePicker`; shows `Fmt.date` |
| `SectionCard` | `SectionCard({required title, required child, trailing})` | Title `titleMedium`, 16 dp padding |
| `ResultHero` | `ResultHero({required label, required value, caption})` | Primary-container card; `label` small on top, big `value`, optional `caption`; wrapped in `Semantics(label: '$label: $value')` |
| `StatRow` | `StatRow({required label, required value, bool emphasize = false, Color? valueColor})` | Label left, value right (tabular), 48 dp min height |
| `EmptyState` | `EmptyState({required icon, required message})` | Centered, muted |
| `InlineBanner` | `InlineBanner({required message, bool isError = false})` | Tonal container with icon; used for warnings |
| `SimpleLineChart` | `SimpleLineChart({required List<double> values, String Function(int index)? xLabel, bool stepped = false, double height = 160})` | `CustomPainter`; area under line tinted `primary` @ 12 %; min/max y labels; semantics label summarising first/last/min/max |
| `SplitBar` | `SplitBar({required List<SplitPart> parts})` `SplitPart(label, value, color)` | Horizontal 12 dp stacked bar + legend with `Fmt.money` and % |
| `Disclaimer` | `Disclaimer(String text)` | `bodySmall`, `onSurfaceVariant` |

`Fmt` (`core/format.dart`): `money(double)`, `percent(double, {int dp = 2})`, `date(DateTime)` → `1 Apr 2025`, `monthYear(DateTime)` → `Apr 2025`, `duration(int months)` → `25 yrs 0 mo` (`1 yr 6 mo`, `8 mo`).

## 7. Screens

Wireframes are schematic; spacing per §2. Strings in `backticks` are exact.

### 7.1 MAB Calculator

```
┌ MAB Calculator          [⤓ Import CSV] [↺ Reset] ┐
│ ┌ Opening balance ────────────────────────────┐ │
│ │ [ $ Opening balance           ]              │ │
│ │ [ 📅 Opening date  1 Apr 2025 ]              │ │
│ │ Billing cycle: 1 Apr 2025 – 30 Apr 2025 (30 days) │
│ └──────────────────────────────────────────────┘ │
│ ┌ Transactions ──────── [+ Add transaction] ──┐ │
│ │ Date         Name           Amount        │ │
│ │ 30 Apr 2025  Transfer      +$150.00   🗑 │ │
│ │ 30 Apr 2025  Food            -$3.00   🗑 │ │
│ └──────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────┐ │
│ │ Monthly Average Balance                      │ │
│ │ $504.90                                      │ │
│ └──────────────────────────────────────────────┘ │
│ ┌ Summary ─────────────────────────────────────┐ │
│ │ Lowest daily balance            $500.00      │ │
│ │ Highest daily balance           $647.00      │ │
│ │ Days in cycle                        30      │ │
│ │ Transactions counted                  2      │ │
│ └──────────────────────────────────────────────┘ │
│ ┌ Daily balance (step chart) ──────────────────┐ │
│ ┌ ▸ Daily balances (30 days) ──────────────────┐ │
└──────────────────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Opening balance field | label `Opening balance`, prefix `$`, `allowNegative: true`. Error: `Enter a valid amount` |
| Opening date | `DateField` label `Opening date`, default today. Changing it recalculates the cycle caption `Billing cycle: <d MMM yyyy> – <d MMM yyyy> (<n> days)` |
| `Add transaction` | `FilledButton.tonal` in the card header → modal bottom sheet |
| Transaction sheet | Title `Add transaction` / `Edit transaction`. `SegmentedButton` `Deposit` ‹default› / `Withdrawal`. Fields: `Name` (optional, blank → `Transaction`), `Date` (`DateField`, default = opening date), `Amount` (positive number). Buttons `Cancel`, `Save`. Errors: `Enter a valid amount` (empty / ≤ 0 / NaN), `Date must be within the billing cycle` |
| Transactions table | Header row `Date` · `Name` · `Amount` (muted `labelLarge`) + 48 dp action column. One row per transaction, divider between rows: date (`1 Apr 2025`), name (max 2 lines, ellipsis), signed amount right-aligned (green `+$150.00` / red `-$3.00`), trailing icon button tooltip `Delete transaction`. Date/amount cells scale down rather than wrap. Tap row → edit sheet. Sorted by date then insertion order. Header only shown when there is ≥ 1 transaction |
| Empty transactions | `No transactions yet. Add deposits and withdrawals made during the month.` |
| Results gating | If opening balance empty/invalid → `EmptyState` `Enter an opening balance to see your Monthly Average Balance.` |
| Hero | label `Monthly Average Balance`, value `Fmt.money(mab)` |
| Summary rows | `Lowest daily balance`, `Highest daily balance`, `Days in cycle`, `Transactions counted` |
| Ignored warning | `InlineBanner` (warning): `1 transaction is outside the billing cycle and was ignored: Salary (5 May 2025)` — plural-aware, lists names+dates |
| Chart | Card `Daily balance`, `SimpleLineChart(stepped: true)`, x labels day-of-month |
| Daily list | `ExpansionTile` titled `Daily balances (30 days)`; rows `1 Apr 2025` ↔ `$500.00`; collapsed by default |
| `Import CSV` (app bar) | Dialog: title `Import from CSV`; multiline field label `Paste CSV`; helper shows the 3-line sample format; buttons `Cancel`, `Import`. Errors from the parser listed under the field in red; on success dialog closes, data replaced, snackbar `Imported 2 transactions` (plural-aware). |
| `Reset` (app bar) | Confirm dialog `Clear all data?` / `This removes the opening balance and all transactions.` buttons `Cancel`, `Clear` |
| Persistence | Everything on this tab (balance — even if blank, date, transactions) is auto-saved to local storage after every change (`MabStore`, JSON in `shared_preferences`) and restored at launch. It is removed **only** by `Reset` → `Clear`. Corrupt data → start empty, no crash |

### 7.2 Interest Calculator

```
┌ Interest Calculator ─────────────────────────────┐
│ [  Simple  |  Compound  ]   (SegmentedButton)     │
│ [ $ Principal                ]                    │
│ [ Annual interest rate     % ]                    │
│ [ Years      ] [ Months      ]                    │
│ [ Compounding ▾ Monthly      ]   (compound only)  │
│ [ $ Monthly contribution (optional) ]             │
│ ┌ Final balance ───────────────────────────────┐ │
│ │ $16,470.09                                   │ │
│ └──────────────────────────────────────────────┘ │
│ Initial principal / Total contributions / Total interest │
│ [ split bar ]  [ growth chart ]                   │
│ ▸ Year by year (table)                            │
│ Estimates only — not financial advice.            │
└──────────────────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Type | `SegmentedButton` `Simple` / `Compound` ‹default Compound› |
| Fields | `Principal` ($), `Annual interest rate` (suffix `%`), `Years` (default `10`), `Months` (default `0`), `Compounding` dropdown — options `Annually`, `Semi-annually`, `Quarterly`, `Monthly` ‹default›, `Daily` (hidden when Simple), `Monthly contribution (optional)` ($) |
| Errors | Principal: `Enter a valid amount`. Rate: `Enter a rate between 0 and 100`. Term: `Enter a term between 1 month and 100 years`. Contribution: `Enter a valid amount` |
| Empty state | `Enter a principal and an interest rate to see your results.` |
| Hero | label `Final balance` |
| Stats | `Initial principal`, `Total contributions`, `Total interest` (emphasised) |
| Split bar | Principal / Contributions / Interest (omit zero parts) |
| Chart | Card `Growth over time` — monthly balances, x labels in years |
| Table | `ExpansionTile` `Year by year` (collapsed). Header: `Year` · `Interest` · `Balance`. Final partial year labelled e.g. `11*` with footnote `* partial year` when months % 12 ≠ 0 |

### 7.3 Mortgage Calculator

```
┌ Mortgage Calculator ─────────────────────────────┐
│ [ Loan amount | Property price ]  (SegmentedButton)│
│  — Loan amount mode: [ $ Loan amount ]             │
│  — Property price mode: [ $ Property price ]       │
│       [ Down payment ] [ $ | % ]                   │
│       Loan amount: $400,000                        │
│ [ Annual interest rate     % ]                     │
│ [ Loan term (years) ]                              │
│ [ $ Extra monthly payment (optional) ]             │
│ ┌ Monthly payment ─────────────────────────────┐  │
│ │ $2,639.18                                    │  │
│ └──────────────────────────────────────────────┘  │
│ Loan amount / Total interest / Total paid / Payoff date / Loan term │
│ (if extra > 0) ┌ With extra payments ┐             │
│   Interest saved / Time saved / New payoff date    │
│ [ principal vs interest split bar ]                │
│ Amortisation schedule  [ Yearly | Monthly ]        │
│  Year   Principal   Interest   Balance             │
└──────────────────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Mode | `SegmentedButton` `Loan amount` ‹default› / `Property price` |
| Loan amount mode | field `Loan amount` ($) |
| Property price mode | `Property price` ($), `Down payment` (number) + `SegmentedButton` `$` / `%` ‹default `%`›; derived caption `Loan amount: $400,000.00`. Error if down payment ≥ price: `Down payment must be less than the price` |
| Other fields | `Annual interest rate` (%), `Loan term (years)` (default `25`), `Extra monthly payment (optional)` ($) |
| Errors | Loan: `Enter a valid amount`; Rate: `Enter a rate between 0 and 30`; Term: `Enter a term between 1 and 40 years` |
| Empty state | `Enter a loan amount and an interest rate to see your monthly payment.` |
| Hero | label `Monthly payment` |
| Stats | `Loan amount`, `Total interest`, `Total paid`, `Payoff date` (`Fmt.monthYear`), `Loan term` (`Fmt.duration`) |
| Extra-payment card | Title `With extra payments`; rows `Interest saved`, `Time saved`, `New payoff date`. Hidden when extra = 0 |
| Split bar | Principal / Interest |
| Schedule | Card `Amortisation schedule` + `SegmentedButton` `Yearly` ‹default› / `Monthly`. Yearly header `Year` · `Principal` · `Interest` · `Balance`; monthly header `#` · `Principal` · `Interest` · `Balance`. Rendered lazily (`SliverList`/`ListView.builder`) — monthly can be 480 rows |

### 7.4 CPF Interest Calculator

```
┌ CPF Interest Calculator ─────────────────────────┐
│ [ Below 55 | 55 & above ]   (SegmentedButton)     │
│ ┌ Current balances ────────────────────────────┐ │
│ │ [ $ Ordinary Account (OA)   ]                 │ │
│ │ [ $ Special Account (SA)    ] / Retirement Account (RA) at 55+ │
│ │ [ $ MediSave Account (MA)   ]                 │ │
│ └──────────────────────────────────────────────┘ │
│ ▸ Monthly contributions (optional)                │
│ ▸ Interest rates (editable)                       │
│ [ Projection years  5 ]                           │
│ ┌ Total CPF balance after 5 years ─────────────┐ │
│ │ $…                                           │ │
│ └──────────────────────────────────────────────┘ │
│ Total interest earned / Basic interest / Extra interest │
│ OA / SA|RA / MA  final balances                   │
│ ▸ Year by year                                    │
│ disclaimer                                        │
└──────────────────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Age band | `SegmentedButton` `Below 55` ‹default› / `55 & above`. Switching to 55+ relabels the SA field to `Retirement Account (RA)` and keeps the typed value |
| Balances | `Ordinary Account (OA)`, `Special Account (SA)` \| `Retirement Account (RA)`, `MediSave Account (MA)` — all $, ≥ 0, blank = 0. Error `Enter a valid amount` |
| Contributions | `ExpansionTile` `Monthly contributions (optional)` → `OA contribution`, `SA contribution` \| `RA contribution`, `MA contribution` ($ per month) |
| Rates | `ExpansionTile` `Interest rates (editable)` → `OA rate` (2.5), `SA/RA rate` (4), `MA rate` (4), suffix `%`; text button `Reset to defaults`. Error `Enter a rate between 0 and 10` |
| Years | `Projection years` default `5`, integer 1–40, error `Enter 1 to 40 years` |
| Gating | Results always shown when inputs valid (all-blank balances = 0 is valid → $0.00) |
| Hero | label `Total CPF balance after 5 years` (N substituted; `1 year` singular) |
| Stats | `Total interest earned`, `Basic interest`, `Extra interest` |
| Final balances | Row group `Ordinary Account (OA)` / `Special Account (SA)`\|`Retirement Account (RA)` / `MediSave Account (MA)` each with final value |
| Table | `ExpansionTile` `Year by year`: header `Year` · `Interest` · `Total balance` |
| Disclaimer | `Estimates only. Interest is calculated monthly on the lowest balance, credited every 31 Dec, and extra interest goes to your SA (below 55) or RA (55 and above). Projection assumes it starts on 1 Jan. Check cpf.gov.sg for current rates.` |

### 7.5 Settings

| Element | Spec |
|---|---|
| Appearance list | One card with two list tiles (leading icon, title, current value as subtitle, chevron). Choices are made in **pop-up dialogs**, never inline. |
| `Theme` tile | Subtitle = current mode (`System` ‹default› / `Light` / `Dark`). Tap → dialog `Theme` with radio list `System`, `Light`, `Dark`; picking one applies instantly, closes the dialog, persists (`theme_mode_v1`). |
| `Color theme` tile | Leading dot in the current colour; subtitle = preset name or `Custom (#RRGGBB)`. Tap → dialog `Color theme` with a wrapped swatch grid (circle + label; selected = check + thick border): `Default` (teal), `Light blue`, `Light green`, `Light red`, `Light orange`, `Light purple`, `Light yellow`, `Custom`; button `Cancel`. Picking a preset applies, closes, persists (`theme_seed_v1`). Each preset is a Material 3 seed (`ColorScheme.fromSeed`) so contrast stays AA. `Custom` opens a second dialog `Pick a color`: live preview + `#RRGGBB`, sliders `Hue` / `Saturation` / `Brightness`, buttons `Cancel` / `Select`; `Select` applies and closes both dialogs. |
| `Share app` | List tile, subtitle `Send the MoneyKit app to a friend`. Opens the Android share sheet with the installed APK (`MoneyKit.apk`) plus the text `MoneyKit: free offline calculators for MAB, interest, mortgage and CPF interest.`; falls back to text only if the APK cannot be copied. Failure → SnackBar `Could not open the share sheet`. |
| `Open-source licences` | List tile → Flutter `LicensePage`. |
| About card | Title `About`; row `Version` (e.g. `1.0.0`); text `MoneyKit works fully offline. Nothing you enter leaves your device.` |
| Footer | `Estimates only — not financial advice.` |

### 7.6 Bill Split

Ported from the `bentong-trip` budget calculator (PLAN §3.5). AppBar action `Reset` (confirm `Clear trip data?` / `This removes all people, expenses and kitty contributions.`, `Cancel` / `Clear`). `SegmentedButton` `Settlement` ‹default› / `Quick split`.

**Quick split:** `Bill amount` ($, error `Enter a valid amount`); `Number of people` stepper (`Fewer people` / `More people` icon buttons, 1–99, default 3); chip group `Tax & service charge`: `None (0%)` ‹default›, `6% SST`, `10% Service`, `16% Combined`; chip group `Rounding`: `Exact (cents)` ‹default›, `Round to $1`, `Round up ($1)`. Empty state `Enter a bill amount to split it.` Hero `Each person pays` (caption `Split by 3 people`); card `Breakdown`: `Base bill`, `Tax / service charge` (only if > 0), `Total bill`, `Total after rounding` (only if rounding on); button `Copy breakdown` → clipboard + SnackBar `Bill split copied`.

**Settlement:** cards in order
- `People`: input chips (delete tooltip `Remove <name>`), field `Add person` + icon button `Add person` (Enter also adds).
- `Expenses` (+ `Add expense`) and `Kitty contributions` (+ `Add contribution`): table `Note` · `By` · `Amount` + delete (tooltip `Delete expense` / `Delete contribution`); tap row to edit. Sheet: title `Add expense` / `Edit expense` / `Add contribution` / `Edit contribution`; fields `Amount`, `Paid by` / `Contributed by` (dropdown: `Unassigned` + people), `Note (optional)`; `Cancel` / `Save`; error `Enter a valid amount`. Empty texts `No expenses yet. Add what each person paid for.` / `No contributions yet. Add money put into the shared kitty.`
- No people → `Add the people sharing the trip to see who owes whom.`
- Otherwise: hero `Fair share per person`; card `Summary` (`Total shared pool`, `Members`); card `Member balances` (avatar initial, name, `Paid: $x`, right: `+$30.00 (gets back)` / `-$30.00 (owes)` / `Settled`); card `Settlement transfers (N)` (rows `B → A` + amount, tap toggles a paid check mark + strike-through; `All settled up!` when none and pool > 0; `Add expenses or contributions to see transfers.` when pool is 0); button `Copy summary` → SnackBar `Settlement summary copied`.
- Everything in Settlement mode is auto-saved locally and removed only by `Reset` → `Clear`.

## 8. Accessibility

- Every input has a persistent visible `labelText` (also what TalkBack reads). Icon-only buttons always have a `tooltip`.
- Touch targets ≥ 48×48 dp. Contrast ≥ WCAG AA (guaranteed by `fromSeed` roles; never hard-code greys).
- Hero/result values wrapped in `Semantics(label: '<label>: <value>')`. Charts expose a text summary via `Semantics`.
- Colour is never the only signal: amounts carry `+`/`-` signs.
- Supports system font scale up to 2×: no fixed-height text containers.

## 9. Testability rules (black-box QA depends on these)

1. Visible text equals the exact strings above — QA locates elements through the Android accessibility tree (`uiautomator`), so text/content-desc **must** be present.
2. Each `NumberField`/`DateField` label is unique within a screen.
3. Result values are real `Text` widgets (not painted on canvas) so they appear in the accessibility tree.
4. No auto-dismissing UI other than SnackBars (≥ 4 s).
5. The release build has no debug banner (`debugShowCheckedModeBanner: false`).
