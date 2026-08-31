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
