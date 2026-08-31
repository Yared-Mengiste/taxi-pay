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
2. Permissions + onboarding flow (restricted settings, battery exemption)
3. Local database schema (sessions, payments)
4. The teleBirr SMS parser + sender validation
5. Background SMS handler
6. Reconciliation query on resume
7. Session start/stop logic + persistence
8. Live session screen
9. Dashboard + charts
10. CSV export
11. Amharic localization
12. Polish pass: theming, dark mode, empty states

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
