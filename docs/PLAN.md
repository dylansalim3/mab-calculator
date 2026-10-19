# MoneyKit — Product Spec, Technical Plan & Task Breakdown

Standalone, offline Flutter (Material 3) Android app. No backend, no network, no accounts.
Four calculators in one app: **MAB**, **Interest**, **Mortgage**, **CPF Interest**.

- Source of truth for MAB behaviour: `../main.go` (Go CLI in this repo). It is kept as the reference oracle.
- UI/UX source of truth: [`UI_DESIGN.md`](UI_DESIGN.md).
- App lives in `../mobile/` (Flutter project, package `com.dylansalim.moneykit`).

---

## 1. Assumptions (made without asking; change them here before build if wrong)

| # | Assumption | Impact if wrong |
|---|---|---|
| A1 | Market is **Singapore** (CPF is SG-only, MAB is the SG bank term). Currency symbol is `$`, same as the Go tool. | Symbol is one constant (`Fmt.currencySymbol`). |
| A2 | Android only, `minSdk` = Flutter default, portrait-first but must not break in landscape. | None. |
| A3 | App name "MoneyKit", package `com.dylansalim.moneykit`. | One-line rename. |
| A4 | Release APK is signed with a **locally generated keystore** (sideload-ready). Play Store upload needs the AAB + your own upload key policy. | Re-sign / re-build. |
| A5 | CPF rates default to those published by CPF Board at time of writing (OA 2.5 %, SA/MA/RA 4 %, extra 1 % on first $60k, +1 % on first $30k at 55+, OA capped at $20k inside the extra-interest base). Rates are **editable** in the UI because CPF reviews them quarterly. | User edits rates. |
| A6 | Mortgage = standard fixed-rate amortising loan, monthly payments in arrears. No SG-specific stamp-duty / TDSR / MSR logic. | Out of scope. |
| A7 | Light + dark theme following the system. English only. | None. |
| A8 | Only MAB data is persisted (last session, via `shared_preferences`). Other calculators keep state for the app session only. | Easy to extend. |

## 2. Scope

### In scope
1. **MAB calculator** — faithful port of `main.go` plus a mobile-native input UI (form, not file picker) and CSV *paste* import in the original CSV format.
2. **Interest calculator** — simple and compound interest, optional monthly contribution, year-by-year table, growth chart.
3. **Mortgage calculator** — monthly payment, total interest, optional extra monthly payment (interest saved / months saved), amortisation schedule (yearly summary + monthly detail), principal-vs-interest split bar.
4. **CPF interest calculator** — OA/SA(RA)/MA projection with CPF rules (below).
5. **Split tab** — bill-split & trip-settlement calculator ported from the `bentong-trip` app's `BudgetTab.jsx` (quick even split with tax/rounding; per-person fair share + who-pays-whom transfers).
6. **Settings tab** (last tab): theme System/Light/Dark (persisted), share app (APK + text), about/version, licences.
7. Material 3, light/dark, accessible, works offline, release-signed APK.

### Non-goals (YAGNI — do not build)
Accounts/cloud sync, multi-currency, exporting PDFs, CPF contribution-from-salary calculator, CPF housing refund / accrued interest, Retirement-sum top-ups, property stamp duty / TDSR, floating-rate mortgages, iOS build, localisation, analytics, ads.

## 3. Functional requirements & golden test vectors

All money maths uses `double`; display rounds to 2 dp. Tests compare with tolerance `1e-2` unless noted.
**Dates are date-only** (`DateTime(y, m, d)`, local, no time part).

### 3.1 MAB (port of `main.go`)

Inputs: opening balance (can be negative), opening date, list of transactions `(name, date, signed amount)`.

Algorithm (this is the spec — the Go code has a latent bug, see "Deliberate deviation"):
1. Billing cycle = **calendar month containing the opening date**: `cycleStart = 1st`, `cycleEnd = last day`.
2. For each day `d` in `[cycleStart, cycleEnd]`: `balance(d) = opening + Σ amount of transactions with date ≤ d` (transactions are applied on their own date, i.e. end-of-day balance includes them; this matches the Go code).
3. The opening balance applies from `cycleStart` regardless of whether the opening date is the 1st (matches Go).
4. `MAB = Σ balance(d) / numberOfDays`. Also report `min`, `max`, `days`.
5. Transactions whose date is outside the cycle month are **excluded and reported** in `ignored` (UI shows a warning banner listing them).

*Deliberate deviation from Go:* `main.go` matches transactions by `Date.Day()` only, so a transaction dated 5 May would be applied on 5 April. The port compares full dates. For all in-cycle data the results are identical.

CSV paste format (same as `balances.csv`):
```
Account,Date,Balance
"Start Amount","1 April, 2025",500.00
"Transfer","30 April, 2025",150.00
"Food","30 April, 2025",-3.00
```
Header row is skipped; first data row = opening balance; remaining rows = transactions. Date format `D Month, YYYY` (English month name, case-insensitive; also accept `YYYY-MM-DD`). Quoted fields may contain commas. Bad rows are collected as human-readable errors (`"Row 4: invalid date 'abc'"`) rather than silently dropped; if the opening row is bad no input is produced.

Golden vectors:
| ID | Input | Expected |
|---|---|---|
| MAB-1 | The `balances.csv` above | cycle 2025-04-01..2025-04-30, 30 days, daily = 500.00 for Apr 1–29 and 647.00 for Apr 30, **MAB = 504.90** (verified with `go run main.go`), min 500, max 647 |
| MAB-2 | opening 1000 on 15 Mar 2025, no transactions | 31 days, MAB 1000.00 |
| MAB-3 | opening 1000 on 1 Feb 2024 (leap year), tx −500 on 15 Feb | 29 days; 14 days @1000 + 15 days @500 → MAB = (14000+7500)/29 = **741.3793…** |
| MAB-4 | opening 100 on 1 Apr 2025, tx +50 on 5 May 2025 | tx ignored (listed), MAB 100.00 |
| MAB-5 | opening −200 on 1 Jan 2025, tx +300 on 1 Jan 2025 | daily 100 all month, MAB 100.00 (day-1 tx applies on day 1) |
| MAB-6 | two txs same day, unsorted input order | order of input does not matter |

### 3.2 Interest calculator

Inputs: principal ≥ 0, annual rate % (0–100), term = years + months (total 1 month … 100 years), type (simple | compound), compounding frequency (annually 1, semi-annually 2, quarterly 4, monthly 12, daily 365; compound only), monthly contribution ≥ 0 (default 0, deposited at **end of each month**).

Algorithm — step month by month for `n = years*12 + months` months:
- **Compound**: `g = (1 + r/m)^(m/12)` where `r` = annual rate as fraction, `m` = compounding periods per year. Each month: `interest = bal * (g-1); bal += interest; bal += contribution`. (For no contributions this equals `P·(1+r/m)^(m·t)` exactly.)
- **Simple**: each month `interest = (principal + contributionsSoFar) * r/12`, accumulated but **not** compounded; `contributionsSoFar += contribution` at month end. Balance = principal + contributions + accrued interest.
- Yearly table rows: one per projection year (final partial year allowed): `startBalance, contributions, interest, endBalance`.
- `totalContributions` excludes the opening principal. `totalInterest = finalBalance − principal − totalContributions`.

Golden vectors:
| ID | Input | Expected final balance |
|---|---|---|
| INT-1 | P 10 000, 5 %, 10 y, compound monthly, no contribution | **16 470.09** (interest 6 470.09) |
| INT-2 | same, compounding annually | **16 288.95** |
| INT-3 | same, compounding daily | **16 486.65** |
| INT-4 | P 10 000, 5 %, 10 y, **simple** | **15 000.00** (interest 5 000.00) |
| INT-5 | P 10 000, 5 %, 10 y, compound monthly, +200/month | **47 526.55**; contributions 24 000 |
| INT-6 | P 5 000, 0 %, 2 y, +100/month, compound | 7 400.00, interest 0 |
| INT-7 | P 1 000, 12 %, 1 y 6 m, simple, +0 | 1 180.00 |

### 3.3 Mortgage calculator

Inputs: loan amount > 0 (UI also offers *property price + down-payment (% or $)* which just derives the loan amount), annual rate % (0–30), term years (1–40), extra monthly payment ≥ 0 (default 0), start month (default current month; first payment is the month after).

Algorithm:
- `r = rate/12/100`, `n = years*12`. `payment = r == 0 ? L/n : L·r / (1 − (1+r)^−n)` (scheduled payment, excludes extra).
- Schedule: each month `interest = bal*r; principalPaid = min(payment + extra − interest, bal)`; the final payment is truncated so the balance lands exactly on 0.
- Also compute the baseline (extra = 0) schedule for `interestSaved`, `monthsSaved`.
- `totalPaid = Σ payments`, `totalInterest = totalPaid − L`.
- Row date for payment `k` (1-based) = `DateTime(start.year, start.month + k, 1)`.

Golden vectors:
| ID | Input | Expected |
|---|---|---|
| MTG-1 | L 500 000, 4 %, 25 y | payment **2 639.18**, total interest **291 755.26** (±1), total paid 791 755.26, 300 months |
| MTG-2 | same + extra 500 | **228 months**, total interest **214 087.57** (±1), months saved 72, interest saved ≈ 77 667.69 (±1) |
| MTG-3 | L 120 000, 0 %, 10 y | payment 1 000.00, interest 0 |
| MTG-4 | L 100 000, 3 %, 1 y | 12 rows, last balance exactly 0 |

### 3.4 CPF interest calculator (estimator)

Inputs: age band (**Below 55** | **55 and above**), balances OA, SA-or-RA (label switches by age band), MA; monthly contributions per account (default 0); rates (defaults OA 2.5, SA/RA 4, MA 4; editable); years 1–40.

CPF rules implemented (A5):
- Basic interest per account per month = `balance × rate/12/100` using the **lowest balance of the month**. Contributions are assumed credited at **month end**, so the lowest balance = opening balance of the month.
- **Extra interest** base = `min(OA, 20 000) + SA/RA + MA`.
  - Below 55: `min(base, 60 000) × 1 %/12`.
  - 55+: `min(base, 30 000) × 2 %/12 + min(max(base − 30 000, 0), 30 000) × 1 %/12`.
- Interest is **accrued monthly, not compounded within the year**, then **credited on 31 Dec**: basic interest to its own account; extra interest to **SA (below 55)** or **RA (55+)**. So interest compounds yearly.
- Projection starts on 1 Jan of year 1; each projection year = 12 months, so every year ends with a credit. (Simplification stated in the UI footnote.)
- Result: per-year rows (`oaEnd, saOrRaEnd, maEnd, basicInterest, extraInterest, totalInterest, totalEnd`) and final totals.

Golden vectors (1 year, no contributions):
| ID | Input | Expected |
|---|---|---|
| CPF-1 | <55, OA 20 000, SA 10 000, MA 10 000 | OA int 500, SA 400, MA 400, extra (base 40 000) 400 → total interest **1 700**; end OA 20 500, SA 10 800, MA 10 400 |
| CPF-2 | <55, OA 50 000, SA 50 000, MA 50 000 | OA 1 250, SA 2 000, MA 2 000, extra (base 120 000 → cap 60 000) 600 → total **5 850**; end SA 52 600 |
| CPF-3 | 55+, OA 30 000, RA 30 000, MA 10 000 | basic 750 + 1 200 + 400, extra (base 60 000) 600 + 300 = 900 → total **3 250**; end OA 30 750, RA 30 000 + 1 200 + 900 = **32 100**, MA 10 400 |
| CPF-4 | all balances 0, contributions OA 1 000/mo, 1 year | monthly lowest balance grows: OA interest = 2.5 %/12 × (0+1000+…+11 000) = **137.50**; extra 0 for months with SA/MA = 0 but OA base counts → extra = 1 %/12 × (0+1000+…+11 000) = **55.00** → total **192.50** |
| CPF-5 | 2-year compounding check: CPF-1 inputs, 2 years | year 2 interest is computed on year-1 closing balances (> 1 700) |

### 3.5 Split (bill split & trip settlement — ported from `bentong-trip/src/components/BudgetTab.jsx`)

Currency symbol is the app's `$` (the source used `RM`). The expense *tracker* parts of the source (category bars, dates, filters, server sync) are not ported — only the calculators and the data they need.

**Quick split** — inputs: bill ≥ 0, people (1–99, default 3), surcharge (0 / 6 % SST / 10 % Service / 16 % Combined), rounding (Exact / Round to $1 / Round up $1).
`total = bill × (1 + surcharge)`; `raw = total / people`; per person = exact: `round(raw×100)/100`, round: `round(raw)`, ceil: `ceil(raw)`; `roundedTotal = perPerson × people`.

**Settlement** — inputs: people (names), expenses `(amount, payer?, note)`, kitty contributions `(amount, contributor?, note)`.
- `paid(person) = Σ expenses + Σ contributions` attributed to that person; payments with no/unknown payer are ignored.
- `pool = Σ paid`; `fairShare = pool / people`; `balance = paid − fairShare` (positive = gets back, negative = owes).
- Transfers (only when `pool > 0`): round balances to cents; creditors `> 0.01`, debtors `< −0.01`; sort each biggest-first (ties keep member order); greedily pair biggest debtor with biggest creditor for `min(debt, credit)`, skipping amounts ≤ 0.01.
- Removing a person keeps their payments but marks them unassigned.

| ID | Input | Expected |
|---|---|---|
| SPL-1 | bill 100, 3 people, exact | **$33.33** (rounded total $99.99) |
| SPL-2 | bill 100, 4 people, 6 % SST | surcharge $6.00, total $106.00, **$26.50** each |
| SPL-3 | bill 100, 3 people, 16 %, Round to $1 | **$39.00** (total after rounding $117.00); 0 %, Round up → $34; 0 %, Round → $33 |
| SPL-4 | A, B, C; A paid 90, B paid 30 (expenses), C contributed 60 | pool $180.00, fair share **$60.00**, A +30, B −30, C settled; 1 transfer **B → A $30.00** |
| SPL-5 | A, B, C; A paid 100 | fair share $33.33; transfers B → A $33.33, C → A $33.33 |
| SPL-6 | A, B; A paid 50, unassigned expense 40 | pool $50.00; B → A $25.00 |
| SPL-7 | no people, or nothing paid | no transfers |
| SPL-8 | A, B, C, D; A paid 120, B paid 60 | fair $45.00; C → A 45, D → A 30, D → B 15 |

## 4. Architecture

Plain Flutter, **no state-management package**. `StatefulWidget` + `TextEditingController`s; calculation = pure Dart functions called from `build`/`setState`. Persistence = `shared_preferences` (MAB only). Dependencies: `intl`, `shared_preferences`, `share_plus` (pinned `^10`: newer majors need AGP ≥ 8.12), `path_provider` (share sheet only) — nothing else (no charts library: shared `CustomPainter` widgets).

```
mobile/lib/
  main.dart                  runApp
  app.dart                   MaterialApp, themes, Shell (NavigationBar + IndexedStack)
  core/
    theme.dart               ColorScheme.fromSeed, light/dark, component themes
    format.dart              Fmt.money / percent / date / monthYear / duration
    parse.dart               parseNum(String) → double? (tolerates commas, spaces)
    widgets/                 shared UI kit (see UI_DESIGN.md §6)
  features/
    mab/       mab_models.dart  mab_engine.dart  mab_csv.dart  mab_store.dart  mab_screen.dart
    interest/  interest_models.dart  interest_engine.dart  interest_screen.dart
    mortgage/  mortgage_models.dart  mortgage_engine.dart  mortgage_screen.dart
    calculators/ calculators_screen.dart   (hosts Interest / Mortgage / CPF behind a segmented switcher)
    cpf/       cpf_models.dart  cpf_engine.dart  cpf_screen.dart
    split/     split_models.dart  split_engine.dart  split_store.dart  split_screen.dart
mobile/test/
    core/…  mab/…  interest/…  mortgage/…  cpf/…   (engine unit tests + screen widget tests)
docs/  PLAN.md  UI_DESIGN.md  QA_TEST_CASES.md  QA_REPORT.md
dist/  moneykit-<version>.apk
```

**Contracts first.** `*_models.dart` (data classes) and the *signatures* of `*_engine.dart` / `*_screen.dart` are written by the coordinator in Phase 0 so that all engine and UI tasks can run in parallel. Workers must **not change the public signatures**; if one is wrong, they stop and message the coordinator.

### File ownership (prevents merge conflicts — all workers share one working tree)
- Coordinator owns: `pubspec.yaml`, `main.dart`, `app.dart`, `core/**`, all `*_models.dart`, `android/**`, `docs/**`.
- Each worker owns **only** the files named in its task. Never edit another task's files. Never run `flutter pub add`, `flutter build`, `git commit`, or touch `android/`.
- Allowed commands for workers: `cd mobile && dart format <own files>`, `flutter analyze <own files>`, `flutter test <own test files>`.

## 5. Task breakdown & dispatch

Legend: **C** = coordinator (this session), **S** = Claude Sonnet 5.5 worker (`orca … --agent claude --model claude-sonnet-5-5`), **AG** = Antigravity worker (`--agent antigravity`).

### Phase 0 — Foundation (C, sequential)
| ID | Task | Done when |
|---|---|---|
| P0.1 | Scaffold Flutter project, add deps, `.gitignore`, analysis options | `flutter pub get` ok |
| P0.2 | `core/` theme, formatters, parsing, shared widgets | `flutter analyze` clean |
| P0.3 | Models + engine/screen **stubs** for the 4 features; `app.dart` shell wired to stubs | app compiles, 4 tabs show placeholders |
| P0.4 | Foundation verified (`flutter analyze` clean, core tests green). Nothing is committed — the user reviews and commits | green |

### Phase 1 — Parallel build (8 workers, simple + well-specified)
| ID | Task | Files owned | Agent | Acceptance |
|---|---|---|---|---|
| E1 | MAB engine + CSV parser + tests | `mab_engine.dart`, `mab_csv.dart`, `test/mab/mab_engine_test.dart`, `test/mab/mab_csv_test.dart` | S | MAB-1…6 pass, CSV edge cases (quotes, commas, bad date, blank lines, CRLF) |
| E2 | Interest engine + tests | `interest_engine.dart`, `test/interest/interest_engine_test.dart` | AG | INT-1…7 pass |
| E3 | Mortgage engine + tests | `mortgage_engine.dart`, `test/mortgage/mortgage_engine_test.dart` | S | MTG-1…4 pass |
| E4 | CPF engine + tests | `cpf_engine.dart`, `test/cpf/cpf_engine_test.dart` | S (high effort) | CPF-1…5 pass |
| U1 | MAB screen + store + widget test | `mab_screen.dart`, `mab_store.dart`, `test/mab/mab_screen_test.dart` | S | UI_DESIGN §7.1; golden flow shows 504.90 |
| U2 | Interest screen + widget test | `interest_screen.dart`, `test/interest/interest_screen_test.dart` | AG | UI_DESIGN §7.2 |
| U3 | Mortgage screen + widget test | `mortgage_screen.dart`, `test/mortgage/mortgage_screen_test.dart` | AG | UI_DESIGN §7.3 |
| U4 | CPF screen + widget test | `cpf_screen.dart`, `test/cpf/cpf_screen_test.dart` | S | UI_DESIGN §7.4 |

UI workers code against the engine **signatures**; engines are filled in concurrently. A UI worker's own widget test may only be fully green once its engine worker is done — it should re-run it at the end.

### Phase 2 — Integration & hardening (C)
| ID | Task | Done when |
|---|---|---|
| I1 | Merge/verify all worker output; `flutter analyze` (0 issues) + `flutter test` (all green) | green |
| I2 | Independent code review (`agent-skills:code-reviewer`) of engines + screens; fix findings | no Critical/Important left |
| I3 | Android release config: app label, launcher icon, signing keystore + `key.properties` (git-ignored), R8/shrink on | `flutter build apk --release` ok |
| I4 | Build release APK → `dist/moneykit-1.0.0.apk`, `apksigner verify` | verified |

### Phase 3 — QA (independent black-box subagent)
| ID | Task | Done when |
|---|---|---|
| Q1 | QA agent receives **only** this spec's §3 + `UI_DESIGN.md` (no source code), writes black-box cases to `docs/QA_TEST_CASES.md` | cases cover every golden vector + validation + navigation + dark mode + rotation + persistence |
| Q2 | QA agent boots the AVD (`Pixel_9_Pro`), installs the **release APK**, executes every case through `orca emulator` / `adb` (uiautomator tree + taps + text input), captures screenshots on failure | `docs/QA_REPORT.md` with pass/fail per case |
| Q3 | Coordinator triages failures, fixes, rebuilds APK, QA re-runs failed cases | all pass, or remaining failures explicitly reported |

### Definition of Done (project-wide)
`flutter analyze` 0 issues · `flutter test` all green · release APK installs on emulator and QA report shows all P0/P1 cases passing · docs match behaviour · no network permission in the manifest (verify: release `AndroidManifest` has no `INTERNET`).

## 6. Risks

| Risk | Mitigation |
|---|---|
| Android SDK licences not accepted → Gradle can't build | Check early in Phase 0; ask user to run `flutter doctor --android-licenses` if needed |
| Parallel workers collide | Disjoint file ownership, pubspec frozen, no worker builds/commits |
| CPF rules drift (quarterly rate reviews) | Rates editable; default values in one constant; in-app disclaimer |
| Floating-point display mismatches (e.g. 504.9 vs 504.90) | All display through `Fmt`; tests use tolerance |
| Flutter UI hard to automate black-box | UI_DESIGN §9 testability rules: unique visible labels, `Semantics` on results, no icon-only controls without tooltip |
| Non-Anthropic worker (Antigravity) quality | Contracts + tests as gate; coordinator reviews and `flutter test`s everything before accepting |
