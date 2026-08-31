# Taxi Pay

An offline-first Android app for Ethiopian taxi drivers that tracks **teleBirr
payments** received during a work shift — straight from the SMS confirmations
teleBirr sends to the driver's phone — alongside cash fares and running costs
(fuel above all), with daily/weekly/monthly earnings dashboards.

No backend, no account, no cloud. Everything lives in a local SQLite file on
the driver's phone.

## Features

- **Automatic payment capture** — teleBirr confirmation SMS (from short code
  **127** only) are parsed and recorded in real time, even when the app is
  backgrounded or was killed. Amount, payer, transaction ID and wallet balance
  are extracted; strict sender validation keeps spoofed messages out.
- **Deduplication by design** — a `UNIQUE(transaction_id)` constraint absorbs
  double delivery from the foreground listener, background handler and the
  inbox reconciliation job. Exactly one row survives per payment.
- **Cash fares** — log cash payments into the same session total; edit or
  delete them when mistyped.
- **Expenses & net earnings** — log fuel and other running costs per session;
  every total (live card, shift summary, dashboard) shows gross, expenses and
  **net**.
- **Dashboards** — daily / weekly (Monday-anchored) / monthly revenue bar
  charts, zero-filled buckets, teleBirr-vs-cash split, averages.
- **CSV export** — share any period (this/last week or month, rolling 7/30
  days, everything, or a custom date range) as an Excel-friendly CSV via the
  Android share sheet.
- **Backup & restore** — export the entire SQLite database as one timestamped
  file and park it wherever you trust (WhatsApp, Drive, USB).
- **Payment feedback** — a beep and haptic pulse confirm each captured
  payment without looking at the screen.
- **teleBirr wallet balance** — the latest balance from the newest captured
  SMS, shown on the home card.
- **Amharic first** — full አማርኛ + English localization with Amharic as the
  fallback locale; localized dates and ICU plurals.
- **Dark mode** — Material 3 theming, teal financial identity, follows the
  system setting or a manual choice.

## How it works

```
teleBirr SMS ──▶ broadcast receiver (manifest-declared)
                    │
                    ├── foreground callback ──┐
                    ├── background isolate ───┤──▶ capture pipeline:
                    │                         │     sender == 127?
                    └── inbox reconciliation ─┘     session active?
                                                  parses? → INSERT OR IGNORE
```

Three independent writers share one idempotent pipeline, so missed broadcasts
are recovered by diffing the SMS inbox against the database on app resume
(plus a periodic WorkManager job while a session is active). Money is stored
as integer cents — never doubles.

## Tech stack

| Package | Role |
|---|---|
| `another_telephony` | SMS receiver, background isolate handler, inbox queries |
| `sqflite` | local storage (works from background isolates) |
| `provider` | state management (one `ChangeNotifier` per feature) |
| `fl_chart` | dashboard bar charts |
| `share_plus` | CSV / backup export via the share sheet |
| `workmanager` | periodic mid-shift reconciliation |
| `intl` | Amharic/English dates and number formatting |

Layering rule: **UI never touches SQLite or the SMS plugin** — screens talk
to providers, providers talk to repositories, repositories own the data.

```
lib/
  main.dart            # async bootstrap: settings + DB before runApp
  app.dart             # MaterialApp, theme, locale, nav shell
  models/              # Session, Payment, Expense, FeedItem (sealed)
  data/
    db/                # schema + Session/Payment/Expense repositories
    sms/               # teleBirr parser, capture pipeline, background handler
  services/            # permissions, reconciliation, CSV/backup export, feedback
  providers/           # SessionProvider, DashboardProvider
  screens/             # home, dashboard, onboarding
  widgets/             # payment/expense tiles, cash/expense/edit sheets
  theme/  l10n/        # Material 3 schemes · ARB translations
test/                  # unit + widget tests (86 and counting)
```

## Getting started

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart ≥ 3.13), an Android device or emulator.

```bash
git clone <this-repo>
cd taxi-pay
flutter pub get

# run on a connected device
flutter run

# run the full test suite (host-side, no device needed — sqflite_common_ffi)
flutter test

# static analysis
flutter analyze

# release APK for sideloading
flutter build apk --release
```

> SMS capture only works on a real device with a SIM that receives teleBirr
> confirmations. The parser, database, providers and export logic are all
> covered by host-side tests; `flutter test` needs no phone.

## Android permissions & sideloading

The app needs `RECEIVE_SMS` + `READ_SMS` and is distributed as a sideloaded
APK (Google Play's SMS policy blocks this use case). Android 13+ puts
sideloaded apps in a *restricted settings* state where permission dialogs are
hidden until the user unlocks them — the onboarding flow detects this and
walks the user through **App info → ⋮ → Allow restricted settings**.

A battery-optimization exemption (skippable) keeps capture prompt while the
screen is off; even without it, inbox reconciliation catches any gaps.

## Backup & restore

**Backup:** Settings (gear icon) → *Export backup* → choose a destination in
the share sheet. Produces `taxi-pay-backup_<timestamp>.db`, a byte-for-byte
snapshot of all data.

**Restore:** copy the backup file back over the app's `taxi_pay.db` while the
app isn't running (e.g. via `adb push` or a file manager), then relaunch.

## Documentation

**[WALKTHROUGH.md](WALKTHROUGH.md)** is a guided tour of how the app was
built — 18 steps, one per feature group, each explaining the Flutter/Dart
concepts, the Android-specific behavior, and the bugs the tests caught along
the way. Read it alongside the git history.

## License

All rights reserved — personal project, not yet licensed for reuse.
