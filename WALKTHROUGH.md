# Taxi Pay — A Guided Walkthrough

This document is a **guided tour of how Taxi Pay was built**, written as a
Flutter learning document. Read it alongside the git history: every section
matches one commit (or a small group of commits) and explains

1. the **Flutter/Dart concept** the step demonstrates,
2. **why** it was built that way for *this* app,
3. the **key files and functions** involved (with short excerpts), and
4. **Android-specific behavior** that a pure-Flutter mental model doesn't
   prepare you for.

## What the app is

Taxi Pay is an Android-only app for Ethiopian taxi drivers. teleBirr (Ethiopia's
dominant mobile-money service) sends an SMS confirmation to the *driver's*
phone every time a passenger pays them. During a work shift the driver taps
**Start**; the app captures those SMS confirmations (strictly from teleBirr's
short code **127**), parses out the amount/payer/transaction ID, shows a live
running total, and aggregates everything into daily/weekly/monthly dashboards.
Cash fares can be logged manually so daily totals reflect real income.

It is fully offline: no backend, no cloud sync. It is distributed as a
sideloaded APK (Google Play's SMS policy blocks this use case), which has real
consequences for the permission flow you'll see in step 2.

## Table of contents (filled in as the build progresses)

1. [Project scaffold, dependencies, folder structure](#1-project-scaffold-dependencies-folder-structure)
2. [Permissions + onboarding flow](#2-permissions--onboarding-flow-restricted-settings-battery-exemption)
3. [Local database schema](#3-local-database-schema-sessions--payments)
4. [The teleBirr SMS parser + sender validation](#4-the-telebirr-sms-parser--sender-validation)
5. [Background SMS handler](#5-background-sms-handler-wired-to-the-plugin)
6. [Reconciliation query on resume](#6-reconciliation-query-on-resume-periodic-workmanager-job)
7. [Session start/stop logic + persistence](#7-session-startstop-logic--persistence)
8. [Live session screen](#8-live-session-screen)
9. [Dashboard + charts](#9-dashboard--charts)
10. [CSV export](#10-csv-export)
11. [Amharic localization](#11-amharic-localization)
12. [Polish pass: theming, dark mode, empty states](#12-polish-pass-theming-dark-mode-empty-states)
13. [teleBirr wallet balance on the home card](#13-telebirr-wallet-balance-on-the-home-card)
14. [Payment feedback: beep + haptic](#14-payment-feedback-beep--haptic)
15. [Backup export: sharing the SQLite file](#15-backup-export-sharing-the-sqlite-file)
16. [CSV export with a date-range picker](#16-csv-export-with-a-date-range-picker)
17. [Editable cash entries (SMS receipts stay immutable)](#17-editable-cash-entries-sms-receipts-stay-immutable)
18. [Expense tracking + net earnings (schema migration v2)](#18-expense-tracking--net-earnings-schema-migration-v2)

---

## 1. Project scaffold, dependencies, folder structure

**Flutter concepts: project layout, pubspec dependency management.**

The project was created with `flutter create --platforms android` because this
is an Android-only app — SMS access is impossible for third-party iOS apps, so
we don't even carry the `ios/` folder around.

### Dependencies chosen (and why)

| Package | Why |
|---|---|
| `another_telephony` | SMS: manifest-declared receiver, background isolate handler, inbox queries |
| `sqflite` | SQLite storage that works from background isolates |
| `provider` | Minimal, official state management (a `ChangeNotifier` per feature) |
| `shared_preferences` | Small flags: onboarding done, language, theme mode |
| `fl_chart` | Bar charts for the dashboard |
| `share_plus` | Hand the exported CSV to WhatsApp/Files/etc. |
| `workmanager` | Periodic reconciliation while a session is active |
| `sqflite_common_ffi` (dev) | Lets unit tests run against a real in-memory SQLite on the host machine |

### Folder structure

```
lib/
  main.dart          # entry point: boots bindings, loads settings, runs the app
  app.dart           # MaterialApp, theme, locale wiring
  models/            # plain data classes: Session, Payment
  data/              # storage + SMS plumbing (the "repository" layer)
    db/              #   SQLite open helper + repositories
    sms/             #   teleBirr parser, listener wiring, background handler
  services/          # permissions, reconciliation, CSV export, settings
  providers/         # ChangeNotifiers the UI watches
  screens/           # one folder per screen
  widgets/           # shared components
  theme/             # Material 3 light/dark schemes
  l10n/              # .arb translation files (Amharic + English)
test/                # unit + widget tests
```

The layering rule: **UI (screens/widgets) never touches SQLite or the SMS
plugin directly.** It talks to `providers`, which talk to repositories in
`data/`. That keeps SMS/DB side effects testable without a phone.

### The `main()` entry point

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaxiPayApp());
}
```

`WidgetsFlutterBinding.ensureInitialized()` is required because the app will
call platform-channel plugins *before* `runApp` (initializing the SMS listener
and reading persisted settings). Without it, any plugin call in `main()` throws
"ServicesBinding.defaultBinaryMessenger was accessed before the binding was
initialized".

---

## 2. Permissions + onboarding flow

**Flutter concepts: `WidgetsBindingObserver` lifecycle, `FutureBuilder`,
hand-written platform channels. `Android` concepts: restricted settings,
Doze / battery-optimization exemptions.**

This app cannot work at all without `RECEIVE_SMS` + `READ_SMS`, and it is
*sideloaded* — which collides with an Android 13+ security rule: APKs
installed from outside a store are put in a "restricted settings" state where
**the system silently refuses to show runtime permission dialogs** until the
user explicitly unlocks the app (App info → ⋮ → Allow restricted settings).
A naive "call requestPermissions() and hope" flow would dead-end for every
user. So the onboarding flow is a small state machine that reacts to what
actually happened:

```
welcome ──▶ request SMS ── granted ──▶ battery-exemption step ──▶ home
                │
                └ denied ──▶ show "Allow restricted settings" instructions
                             + button that opens the app's Settings page
```

### Key files

- `android/app/src/main/AndroidManifest.xml` — declares the two SMS
  permissions, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, and (importantly) the
  plugin's manifest-declared `IncomingSmsReceiver`, which lets the OS wake the
  app for every incoming SMS even when it is not running. `another_telephony`
  deliberately does *not* declare this receiver itself — apps opt in.
- `android/.../MainActivity.kt` — a **custom platform channel**
  (`taxi_pay/android`) exposing three Android-only operations:
  `isSmsPermissionGranted`, `requestIgnoreBatteryOptimizations`
  (fires `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) and `openAppSettings`
  (`ACTION_APPLICATION_DETAILS_SETTINGS`).
- `lib/services/android_service.dart` — typed Dart wrapper over the channel.
- `lib/services/permissions_service.dart` — combines the channel with
  `another_telephony`'s `requestPhoneAndSmsPermissions` (which *does* show the
  system dialog when allowed to).
- `lib/screens/onboarding/onboarding_screen.dart` — the 3-step flow.

### Why a custom channel?

Dart plugins already existed for "request SMS permission" — but we needed a
**check without prompting** and **battery-optimization intents**, and writing
~40 lines of Kotlin teaches the platform-channel mechanism that everything
else in Flutter's plugin ecosystem is built on:

```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "taxi_pay/android")
    .setMethodCallHandler { call, result ->
        when (call.method) {
            "isSmsPermissionGranted" -> result.success(isSmsPermissionGranted())
            ...
        }
    }
```

The Dart side (`android_service.dart`) is the mirror image:
`MethodChannel('taxi_pay/android').invokeMethod<bool>(...)`.

### Lifecycle observation

After the user jumps to system Settings, we can't receive an event when they
flip the toggle — so `OnboardingScreen` mixes in `WidgetsBindingObserver` and
re-checks all permission states every time the app **resumes**:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) _refreshStatuses();
}
```

This "re-check on resume" pattern returns later in the reconciliation step,
for the same reason: external state can change while we're not looking.

### Battery exemption, honestly

`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is the pragmatic choice for a
sideloaded utility: without it, **Doze** defers background work (including our
SMS broadcast handling latency) when the screen is off. The step is skippable
because some ROM variants nag about it; SMS still gets captured, just less
promptly — and step 6's reconciliation is designed to catch gaps.

---

## 3. Local database schema: sessions + payments

**Flutter/Dart concepts: SQLite via `sqflite`, repository pattern, money as
integers, testing databases on the host with `sqflite_common_ffi`.**

### The schema

```
sessions(id, started_at_ms, ended_at_ms)          -- ended_at_ms NULL = active
payments(id, transaction_id UNIQUE, session_id → sessions,
         method 'telebirr'|'cash', amount_cents, payer_name, payer_phone,
         balance_after_cents, sms_timestamp_ms, created_at_ms)
```

Three decisions worth internalizing:

**A session row *is* the persisted listening state.** Requirement: "session
state survives the app being killed." The obvious-but-wrong approach is a
`bool isListening` in memory plus something in `SharedPreferences`. Instead,
the *database* holds truth: `SELECT … WHERE ended_at_ms IS NULL` answers both
"is a session active?" and "since when?" in one query, and it is the same
query from any isolate (see step 5 — the SMS background handler has to decide
whether an incoming payment belongs to a session, from a separate isolate,
with no access to the UI's memory).

**Money is `amount_cents INTEGER`, never a double.** `0.1 + 0.2 == 0.30000000000000004`
in binary floating point; a revenue app that occasionally prints
`450.00000000001 ብር` is broken in the way users trust least.

**Dedupe is a database constraint, not a code path.** `transaction_id` is
`UNIQUE` and inserts use `INSERT OR IGNORE`, so the foreground listener, the
background isolate and reconciliation can all try to save the same teleBirr
payment and exactly one row survives — no coordination needed:

```dart
final count = await _db.insert('payments', payment.toRow(),
    conflictAlgorithm: ConflictAlgorithm.ignore);
return count > 0; // false = duplicate, already known
```

### One database, several isolates

`AppDatabase` is deliberately boring: `openDefault()` caches one connection
per isolate (Dart objects can't cross isolate boundaries, and sqflite
connections must not either), sets `PRAGMA foreign_keys = ON` and a
`busy_timeout` so the (rare) case of two isolates writing simultaneously
waits instead of crashing. Tests use `openInMemory()` with the *same*
`onCreate`, so schema tests exercise the real DDL.

### Testing SQLite without a phone

`sqflite` normally talks to Android's SQLite through a platform channel —
which doesn't exist in `flutter test`. The `sqflite_common_ffi` package
provides a pure-Dart SQLite compiled via FFI as a drop-in `databaseFactory`:

```dart
setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });
```

That's why the repositories take an `AppDatabase` (a thin wrapper) rather
than grabbing a singleton themselves — tests inject an in-memory database,
production injects the file-backed one. Constructor injection beats global
singletons precisely when side effects are expensive to fake.

The tests (`test/db_repositories_test.dart`) pin down the behaviors the rest
of the app leans on: start is idempotent (double-tapping Start can't fork two
sessions), duplicate transaction IDs are dropped, cash entries get unique
local IDs, foreign keys reject orphan payments, and `dailyTotals` buckets by
**local** calendar day (`strftime(…, 'localtime')`) — matching the driver's
wall clock, not UTC.

---

## 4. The teleBirr SMS parser + sender validation

**Dart concepts: regular expressions, pure functions, table-driven unit
tests. Domain concept: never trust message text.**

teleBirr confirmation SMS come in (at least) two languages and several
templates that have drifted over the years:

> `You have received Birr 150.00 from ABEBE KEBEDE (0911***234). Your Telebirr
> account balance is Birr 2,450.00. Transaction ID: 881234567890.`

> `ከ ABEBE KEBEDE (0911***234) ብር 150.00 ተቀብለዋል። … ቀሪ ሂሳብ ብር 2,450.00 ነው።
> የግብይት መለያ ቁጥር፦ 881234567890።`

So the parser is not one rigid regex but a component scan
(`lib/data/sms/telebirr_parser.dart`):

1. **Received-ness gate** — the body must contain a received-signal
   (`received`, `ተቀብለዋል`, `ደርሶብዎታል`, …). "You have *sent*" confirmations
   and promo blasts die here.
2. **Balance peel** — templates carry two amounts (payment + resulting
   balance). The balance keyword (`balance` / `ቀሪ ሂሳብ`) is located, the
   currency-attached number nearest *after* it is consumed as the balance and
   blanked out of the working string.
3. **Amount** — the first remaining currency-attached number
   (`Birr 150.00`, `150.00 ETB`, `ብር 150.00` …), thousands-separator aware.
4. **Transaction ID** — mandatory; without it we cannot dedupe, and a partial
   parse would be worse than skipping.
5. **Payer name / masked phone** — optional, `from NAME (09** ***234)` /
   `ከ NAME (…)`.

Everything is a `RegExp` module-level `final` (compiled once), and the whole
function is **pure**: `String? → TelebirrPayment?`. No I/O, no plugin, no
clock — which is exactly why it can be tested exhaustively in
`test/telebirr_parser_test.dart` without a phone or a SIM. When a real
message template doesn't parse, you paste it into that test file as a new
case and fix the regex — the tests are the format catalog.

### The anti-spoofing rule: validate the *address*, not the text

```dart
bool isFromTelebirr(String? address) {
  if (address == null) return false;
  final digits = address.replaceAll(RegExp(r'[^0-9]'), '');
  return digits == '127';
}
```

A scammer can write "You have received Birr 500.00…" in an SMS *body* from
their own number; they cannot make the carrier deliver it *from* 127. So the
capture pipeline (step 5) calls `isFromTelebirr(message.address)` on the PDU
sender address before the body is ever parsed. Parsing and validation are
separate functions on purpose — parsing answers "what does this say?",
`isFromTelebirr` answers "who actually sent it?", and only the pair of them
together means "this is real income".

---

## 5. Background SMS handler wired to the plugin

**Flutter/Android concepts: background isolates, `@pragma('vm:entry-point')`,
why Dart objects can't cross isolates, broadcast streams.**

Android delivers incoming SMS as a system broadcast
(`Telephony.SMS_RECEIVED`). The `another_telephony` plugin's manifest-declared
receiver (which we opted into in step 2) catches it even for a dead app, then
spins up a **background Flutter engine** and calls our Dart handler *on its
own isolate*. Three consequences shaped this code:

1. **Nothing can be shared.** The background isolate has no access to the UI's
   memory — no providers, no open `Database` object. So all state it needs
   must come from storage. That's why step 3 made the *database* the source of
   truth: `captureSmsMessage` opens its own connection
   (`AppDatabase.openDefault()` caches one per isolate), asks SQLite for the
   active session, and writes.

2. **The handler must survive tree-shaking.** The native side reaches the Dart
   function only through a raw callback handle, so the compiler sees no
   static reference to it. Without the pragma, release builds strip it and
   background capture silently stops:

   ```dart
   @pragma('vm:entry-point')
   Future<void> smsBackgroundHandler(SmsMessage message) async {
     await captureSmsMessage(await AppDatabase.openDefault(),
         address: message.address, body: message.body,
         timestampMs: message.date ?? DateTime.now().millisecondsSinceEpoch);
   }
   ```

3. **Double delivery is normal.** The plugin fires the foreground callback
   and the background handler for the same SMS. Instead of coordinating them,
   both call the same pipeline and the `UNIQUE(transaction_id)` constraint
   absorbs the race — the second insert is a no-op.

### The shared pipeline

`lib/data/sms/sms_capture.dart` is one function used by every entry point
(foreground, background, and step 6's reconciliation):

```
address == 127?  →  session active?  →  body parses?  →  tx id new?
     no: drop          no: drop           no: drop        no: ignore
```

Payments that arrive *outside* an active session are deliberately not stored
(v1 scope: the app tracks shift income, not full account history). The same
function is trivially unit-tested with an in-memory database — including the
spoof case: same convincing body, sender `0911223344`, nothing written.

The foreground half (`sms_service.dart`) exposes captured payments as a
**broadcast stream** (`Stream<Payment>`), so later any number of widgets can
listen without polling. `start()` is idempotent and re-armed on every app
launch — after a kill, only the native side remembers the callback handles,
so re-calling `listenIncomingSms` re-registers everything.

---

## 6. Reconciliation query on resume (+ periodic WorkManager job)

**Flutter/Android concepts: pull-based recovery vs push-based capture,
content-provider queries, WorkManager, dependency injection of I/O.**

Broadcasts are best-effort: Doze defers them, aggressive OEM battery savers
drop them, and a killed process races with incoming SMS. But the SMS inbox
is a durable log — the carrier's copy of every message is sitting in the
`content://sms/inbox` content provider regardless of what our process was
doing when it arrived. Reconciliation simply diffs that log against the
database:

```
on app resume ──▶ active session? ──▶ query inbox: address = '127'
                                         AND date >= session.startedAtMs
                              ──▶ for each: captureSmsMessage (same pipeline!)
```

Because inserts go through the *same* `captureSmsMessage` pipeline with the
same `UNIQUE(transaction_id)` constraint, reconciliation is **idempotent** —
run it once or fifty times, the result converges (see
`test/reconciliation_service_test.dart`, which proves a double run inserts
nothing new). That property is what lets three independent writers (foreground
callback, background isolate, reconciliation) share one pipeline with zero
coordination.

### Testable I/O via an injected fetcher

The only untestable part is the actual platform query, so it's isolated
behind a one-function typedef and injected:

```dart
typedef SmsFetcher = Future<List<InboxSmsItem>> Function(int sinceMs);
```

Production passes a wrapper around `Telephony.instance.getInboxSms(filter:
SmsFilter.where(SmsColumn.ADDRESS).equals('127')
    .and(SmsColumn.DATE).greaterThanOrEqualTo(...))` — a real SQL WHERE pushed
down into the content provider, so non-teleBirr messages never even leave the
provider. Tests pass a list literal. The diff logic itself (the part with
bugs in it) runs against real SQLite.

Note the sender filter appears at *both* levels — provider query and the
strict `isFromTelebirr` gate in the capture pipeline. Defense in depth: even
if the provider's address matching ever behaved unexpectedly (alpha senders,
carrier quirks), the pipeline re-validates.

### The resume hook and the WorkManager insurance policy

`app.dart` observes the lifecycle (`didChangeAppLifecycleState` → `resumed`)
and runs reconciliation with a re-entrancy guard, forwarding anything newly
inserted onto the same `Stream<Payment>` the live listener uses — one stream,
one place for the UI to listen. Failures (e.g. READ_SMS revoked) are caught:
a resume path must never crash the app.

On top of that, `BackgroundTaskService` registers a **periodic WorkManager
task** (every 30 minutes, `ExistingPeriodicWorkPolicy.keep` so re-registering
is safe) while a session is active — best-effort mid-shift reconciliation
while the phone stays in the driver's pocket. Its dispatcher is another
top-level `@pragma('vm:entry-point')` function running on its own engine,
reusing `ReconciliationService` unchanged — the "everything through storage"
architecture paying off a second time.

---

## 7. Session start/stop logic + persistence

**Flutter concepts: `ChangeNotifier` + `provider`, constructor injection,
`WidgetsBindingObserver`, why `main()` should own async bootstrap.**

`SessionProvider` (`lib/providers/session_provider.dart`) is the bridge
between the data layer and the UI, and its central design rule is: **the
provider is a cache plus a notifier — the database is the truth.** Every
"read" rebuilds from SQLite (`_reloadActive`), which is why three different
triggers all converge to the same consistent state:

- `load()` — cold start. If a session was running when the process died,
  `activeSession()` still finds it and the UI comes back up in "running"
  mode. Persistence came free from step 3's schema decision.
- `capturedPayments` stream events — a payment was captured while we were
  in the foreground.
- `didChangeAppLifecycleState(resumed)` — the background isolate may have
  written rows we never heard about; reload picks them up.

`start()`/`stop()` also schedule and cancel the periodic WorkManager job —
reconciliation only matters *while a session is active*.

```dart
Future<void> stop() async {
  final session = _activeSession;
  if (session == null) return;
  final endedAtMs = await _sessionsRepo.stopSession();
  await backgroundTasks?.stopPeriodicReconciliation();
  _lastEndedSession = Session(...endedAtMs: endedAtMs...);
  _lastEndedPayments = _payments;   // kept for the shift-summary screen
  _activeSession = null;
  _payments = [];
  notifyListeners();
}
```

### Composition over callbacks

The provider takes the *stream*, not the SmsService:

```dart
SessionProvider({required AppDatabase app,
                 required Stream<Payment> capturedPayments, ...})
```

so tests just pass a `StreamController.broadcast()` they control — no
mocking framework, no service doubles.

### The `main()` refactor

This step moved async bootstrap (SharedPreferences + SQLite open) out of the
widget tree into `main()`, handing both down as constructor arguments. The
widget-test failures that forced this are worth remembering: opening a
*file-backed* database inside `testWidgets` never completes, because the
fake-async test clock never advances real disk I/O. Doing I/O before
`runApp` removes the problem entirely — and as a bonus the widget tree has
no spinners or FutureBuilders: `TaxiPayApp(settings: ..., app: ...)` is
synchronous from its first frame.

---

## 8. Live session screen

**Flutter concepts: `Consumer`/`context.read` split, widget decomposition,
modal bottom sheets, `TextInputFormatter` validation, async-gap context
rules.**

The home screen (`lib/screens/home_screen.dart`) is deliberately two
widgets in one: `_IdleView` (big circular START button + summary of the
shift that just ended) and `_LiveSessionView` (LIVE banner, running total
in `displaySmall`, payment count, Cash + Stop buttons, feed below). The
`Consumer<SessionProvider>` at the top switches between them:

```dart
body: Consumer<SessionProvider>(
  builder: (context, session, _) => session.isRunning
      ? _LiveSessionView(session: session)
      : _IdleView(session: session),
),
```

Why a `Consumer` here and `context.read` inside button callbacks?
`Consumer` rebuilds when the notifier fires (totals, feed); `read` inside
an `onPressed` grabs the provider once without subscribing — exactly what
a fire-and-forget action needs.

### The cash sheet — parse once, validate at the keyboard

`showCashEntrySheet` (`lib/widgets/add_cash_sheet.dart`) returns
`Future<int?>`: cents, or null when dismissed. Two details worth stealing:

- `FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}([.,]\d{0,2})?'))`
  makes an *invalid* amount untypable — the Add button's `num.tryParse`
  is a backstop, not the defense.
- it accepts both `,` and `.` as the decimal separator (keyboard
  layouts vary) and normalizes before parsing.

The wrapper that shows the sheet and writes to the provider captures the
provider *before* the await:

```dart
Future<void> promptAndAddCash(BuildContext context) async {
  final session = context.read<SessionProvider>();  // before the gap
  final cents = await showCashEntrySheet(context);
  if (cents != null && cents > 0) {
    await session.addCash(amountCents: cents);
  }
}
```

Using `context` after an `await` is a lint error (`use_build_context_synchronously`)
for good reason: the widget may be gone by the time the sheet closes.

### A real bug the tests caught

The first teardown of the widget tests produced *"A SessionProvider was
used after being disposed"*: `load()` is async, and its
`notifyListeners()` can land after the test tore the tree down. Guarded
now with a `_disposed` flag — the same race exists in production during
hot restart.

---

## 9. Dashboard + charts

**Flutter concepts: SQL aggregation vs Dart aggregation, `IndexedStack`
navigation shells, third-party charting (`fl_chart`), `switch`
expressions.**

The design question: where does grouping happen? Answer: **SQLite groups
by day (what SQL is good at), Dart groups days into weeks/months (what
calendars are good at)**. One `GROUP BY` query per reload:

```sql
SELECT strftime('%Y-%m-%d', sms_timestamp_ms / 1000, 'unixepoch',
       'localtime') AS bucket,
       SUM(amount_cents), COUNT(*)
FROM payments
WHERE sms_timestamp_ms >= ? AND sms_timestamp_ms < ?
GROUP BY bucket
```

`'localtime'` matters: a driver's "day" is their wall clock, not UTC.
`DashboardProvider` then folds day-buckets into week-buckets
(Monday-anchored — the Ethiopian convention) or month-buckets, and
zero-fills: **an empty day is still a bar on the chart.**

### The `addMonths` trap (an actual bug from this step)

Dart's `~/` truncates toward zero: `(-4) ~/ 12 == 0`, not `-1`. My first
month-window math happily turned "11 months before Aug 2026" into *Sep
2026* — a window from the future to the future, empty query, all-zero
chart, two failing tests. Floor, don't truncate:

```dart
final totalMonths = d.month - 1 + n;
return DateTime(d.year + (totalMonths / 12).floor(), totalMonths % 12 + 1);
```

Pure date helpers (`lib/util/dates.dart`) got their own unit tests the
same day — calendar math is exactly the kind of code that looks obvious
and isn't.

### Navigation shell

`_HomeShell` in `lib/app.dart`: a `NavigationBar` + `IndexedStack`. Both
providers sit *above* the shell in a `MultiProvider`, so tab switches
never destroy session state, and both screens stay alive (scroll
positions, chart state) while hidden. Switching to the dashboard tab
triggers `reload()` so payments captured on the session tab show up.

### `fl_chart` version pinning

`SideTitleWidget` changed its API between versions (`axisSide:` →
`meta:`). The lockfile pins fl_chart 1.2.0; the chart wrapper keeps all
fl_chart types inside `_RevenueBarChart` so a future bump touches one
widget.

### Widget tests + real async work

Adding a second provider that queries the DB on construction broke
`pumpAndSettle` in widget tests: under fake async, the sqflite-ffi
isolate round-trips never complete, the dashboard spinner never stops
settling. The recipe:

```dart
await tester.runAsync(() =>
    Future<void>.delayed(const Duration(milliseconds: 200)));
await tester.pumpAndSettle();
```

`runAsync` suspends the fake clock and lets real async I/O finish.
Rule of thumb: pump-only tests for layout, `runAsync` whenever a
provider's constructor touches ffi/platform channels.

## 10. CSV export

**Flutter concepts: pure-function testing, dependency injection of *side
effects*, platform share sheets (`share_plus`), file I/O in the cache
directory.**

Export follows the same split as the parser: **formatting is a pure
function** (`lib/util/csv.dart` — RFC 4180 escaping, one row per payment,
amounts as birr decimals) **and only the I/O is a service**
(`lib/services/csv_export_service.dart`):

```dart
final exporter = CsvExportService(
  payments,
  onShareFile: ...,   // injectable side effect
  cacheDir: ...,      // injectable, too — getTemporaryDirectory() is a
);                    // platform channel and explodes in unit tests
```

Tests therefore assert on *bytes on disk* with zero platform doubles.

Two details that cost people real afternoons:

- **The UTF-8 BOM.** The file is written as `\uFEFF` + CSV. Without the
  BOM, Excel guesses a legacy 8-bit encoding and Amharic payer names
  open as mojibake. (Fun fact learned here: Dart's `readAsString()`
  strips a leading BOM — assert on `readAsBytes()` if you test this.)
- **`SharePlus.instance.share(ShareParams(files: [...]))`** is the
  current share_plus API; the older `Share.shareXFiles` still exists but
  is deprecated. Version churn in plus_plugins is real — keep plugin
  calls in one small service, not scattered through widgets.

The dashboard's export button exports **exactly the window on screen**
(`DashboardProvider.windowFrom/windowTo`), so "what I see is what I
send" — the summary card, chart and CSV can never disagree.

## 11. Amharic localization

**Flutter concepts: gen-l10n and ARB files, locale resolution, ICU
plurals, rebuilding MaterialApp on settings change.**

The toolchain: two ARB files (`lib/l10n/app_en.arb` template,
`lib/l10n/app_am.arb`) plus `l10n.yaml`, `generate: true` in pubspec.
`flutter gen-l10n` writes real Dart classes into `lib/l10n/` (synthetic
packages are gone in current Flutter), and every screen reads them via a
one-line extension:

```dart
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this); // non-null
}
```

### Amharic is the *primary* language

Requirement, not preference: unsupported device locales must fall back
to Amharic, not English. `MaterialApp` falls back to the *first* entry
of `supportedLocales`, so the order does the work:

```dart
supportedLocales: const [Locale('am'), Locale('en')], // am wins fallbacks
locale: _languageCode == null ? null : Locale(_languageCode!),
```

A user choice (language sheet on the home app bar) writes through
`SettingsService.setLanguageCode` and flips `_languageCode` in
`TaxiPayApp` state — the whole tree relocalizes without a restart,
because `MaterialApp.locale` participates in the normal rebuild.

### Plurals, ICU style

English needs "1 payment / 2 payments"; Amharic has no plural
inflection. gen-l10n handles this with ICU plural messages — the
English ARB declares categories, the Amharic one declares only
`other`, which CLDR-style fallback covers for am:

```json
"paymentsCount": "{count, plural, =1{{count} payment} other{{count} payments}}"
"paymentsCount": "{count, plural, other{{count} ክፍያ}}"
```

### Localized dates (the limitation, closed)

v1 originally shipped Gregorian/English date labels (`Mon`, `Aug 31`)
on the payment feed and chart axes. Closing that meant two things:

- `await initializeDateFormatting()` in `main()` before `runApp` —
  intl keeps date symbols per-locale on disk, and loading them lazily
  means the *first* localized `DateFormat` call would throw mid-frame.
- Locale threading instead of static formatters. `lib/util/dates.dart`
  now keys its `DateFormat` cache by `pattern|locale`, and every
  formatter takes `locale:` — widgets pass
  `Localizations.maybeLocaleOf(context)?.toString()` down. So the
  dashboard's weekday axis reads `ሰኞ` when the app is Amharic and `Mon`
  in English, from the same widget code.

Numbers and clock times (`14:35`) stay locale-neutral by design —
Ethiopian taxi fare negotiation runs on western-Arabic digits in
practice, and mixing Ethiopic numerals into money would hurt
scannability more than it helps authenticity.

## 12. Polish pass: theming, dark mode, empty states

**Flutter concepts: `ColorScheme.fromSeed`, `themeMode` vs `darkTheme`,
state-driven settings, `SystemChrome`.**

`lib/theme/app_theme.dart` owns the identity: a deep teal seed
(`0xFF006A60`) — financial, trustworthy, adjacent to teleBirr's green —
with a warm amber `secondary` reserved as the **cash accent**, so cash
and teleBirr are visually distinct in every list, chip and icon without
touching the error color. Light and dark are both derived from the same
seed (`ColorScheme.fromSeed` with explicit `brightness`), so containers,
outlines and surfaces stay harmonized in both modes rather than
inverted.

Theme *mode* flows exactly like language: settings sheet (home app bar)
→ `SettingsService.setThemeModeName` → `_TaxiPayApp.setState` →
`MaterialApp(themeMode:)`. `MaterialApp` resolves `system`/`light`/
`dark` against the OS setting; no `MediaQuery.platformBrightness`
plumbing anywhere in app code.

```dart
theme: AppTheme.light(),
darkTheme: AppTheme.dark(),
themeMode: _themeMode, // system by default, user choice wins
```

`main()` also locks the app portrait — one-handed use in a car — via
`SystemChrome.setPreferredOrientations`, the one-line platform hedge
that saves a scramble of weird states on cheap devices.

### Empty states were designed, not defaulted

Each "nothing here" is a real composition: the live feed's waiting state
explains what will happen (payments appear instantly) and offers the
cash entry; the dashboard's empty card explains *why* it's empty and
what fills it; onboarding never shows a bare screen. The general
pattern: **say what's missing, say why it matters, offer the action
that fixes it.**

### The last fake-async footgun (for the road)

The dark-mode launch test hung for a while: `AppDatabase.openInMemory()`
was called *inside* the `testWidgets` body, and an ffi isolate
round-trip awaited directly under fake async never completes — the test
never even reached its first `print` (which itself was invisible,
because the runner buffers stdout of unfinished tests). Rule, one final
time: **open platform resources in `setUp`, settle real async with
`runAsync`, close in `tearDown`.**

---

## 13. teleBirr wallet balance on the home card

**Flutter concept: letting a "nearly free" feature stay nearly free.**

The parser already extracts `balance_after_cents` from every confirmation
SMS and the payments table already stores it (step 3/4). Surfacing "Wallet:
2,450.00" is exactly one query and one getter — the discipline this step
practices is *not inventing machinery* around that:

```sql
SELECT balance_after_cents FROM payments
WHERE method = 'telebirr' AND balance_after_cents IS NOT NULL
ORDER BY sms_timestamp_ms DESC, id DESC LIMIT 1
```

`PaymentRepository.latestTelebirrBalanceCents()` wraps it, and
`SessionProvider._reloadActive()` folds it into the *existing* reload
path — no new stream, no new provider. Any of the three triggers that
already rebuild the session (cold start, captured-payment event, app
resume) refreshes the balance too. That's the payoff of "the provider is
a cache, the DB is the truth": a new read is one line inside the
existing refresh, not a new lifecycle to manage.

One honest design note in the widget doc comment: the badge is a *hint*,
not ledger truth — it goes stale the moment the driver pays someone
outside the app. So it renders as a small `labelMedium` row on the live
card (and under the START button when idle), not as a headline number.

---

## Build order recap

| Commit | What it taught |
| --- | --- |
| scaffold | project shape, dependency choices |
| permissions onboarding | runtime permissions, Android restricted settings, battery exemption |
| DB schema | SQLite via sqflite, integer cents, UNIQUE dedupe |
| SMS parser | pure-Dart regex parsing, strict sender validation |
| background handler | `@pragma('vm:entry-point')` background isolates |
| reconciliation | inbox diffing as the correctness guarantee |
| session logic | ChangeNotifier over a DB-as-truth model |
| live session UI | Consumer/read split, bottom sheets, async-gap rules |
| dashboard | SQL vs Dart aggregation, IndexedStack shells, fl_chart |
| CSV export | pure formatting + injected side effects, share sheets |
| localization | gen-l10n, ICU plurals, am-first fallbacks |
| polish | seeded theming, dark mode, designed empty states |
| wallet balance | one SELECT + one getter; keeping a cheap feature cheap |
| payment feedback | streams as side-effect buses, injectable haptics |
| backup export | file I/O services, WAL checkpoints, share sheets again |
| CSV date range | preset windows as pure date math |
| cash edit/delete | immutability by WHERE clause, not by UI hiding |
| expenses + net | schema v2 migration, gross vs net everywhere |
