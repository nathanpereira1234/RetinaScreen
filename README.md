# RetinaScreen — Phase 1

Companion and last-mile app. Referral tracking, reminders, plain-language
result explanation.

**This app does not diagnose.** A human enters the screening result; the app
explains it and chases the follow-up. That line is what keeps Phase 1 outside
SaMD, and it constrains every feature decision. Before adding anything that
outputs a clinical judgement, re-read B08.

---

## Bootstrap (do this once)

This repo contains hand-written source only — no Flutter scaffolding. Generate
the platform folders, then drop these files in:

```bash
flutter create --org com.yourcompany --platforms=android retinascreen_tmp
cp -r retinascreen_tmp/android retinascreen_tmp/.metadata .
rm -rf retinascreen_tmp

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

`build_runner` generates `lib/data/database.g.dart`. Until it has run, your
editor will show errors on every Drift symbol — that is expected, not broken.

Rerun it after **any** change to a table definition:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Verify A12 is actually done

The Definition of Done is persistence, not a screen that renders:

1. `flutter run` on a real phone.
2. Add a patient.
3. Force-kill the app from the recents switcher (not hot restart).
4. Reopen. The patient is still listed.

If step 4 fails, the data layer is not done regardless of how the UI looks.

---

## Architecture

```
lib/
  data/database.dart        Drift tables, queries, referral transaction
  models/enums.dart         ScreeningResult, ReferralStatus, state machine
  providers/app_providers.dart   THE CONTRACT — A's output, B's input
  screens/                  UI (Person B)
  theme/app_theme.dart      Design tokens (A05)
  services/                 Notifications, url_launcher (A15–A18)
```

Data flows one way: **Drift → provider → widget**. Widgets never construct a
database, never hold a `Screening` they mutate, never call `setState` for data
that lives in the DB.

### The provider contract (A11)

Person B imports `providers/app_providers.dart` and nothing from `data/`.

**Reads** — all streams, so the UI refreshes itself after any write:

| Provider | Gives you |
|---|---|
| `patientListProvider` | `List<Patient>`, newest first |
| `patientProvider(id)` | one `Patient?` |
| `screeningsProvider(patientId)` | that patient's screening history |
| `pendingReferralsProvider` | referred-or-booked, not yet attended |
| `pendingReferralCountProvider` | count for the home badge |
| `referralHistoryProvider(screeningId)` | audit trail for the timeline UI |

**Writes** — through `patientRepositoryProvider`:

```dart
await ref.read(patientRepositoryProvider).addPatient(
  name: 'Asha K', phone: '9876543210', age: 54,
);

await ref.read(patientRepositoryProvider).advanceReferral(
  screeningId: 12, to: ReferralStatus.attended,
);
```

`advanceReferral` throws `InvalidReferralTransition` on an illegal move.
Catch it and show `from.nextStates` — do not swallow it.

If a screen needs data this file doesn't expose, that's a request to Person A
at the daily sync, not a reason to import `data/` directly.

---

## Reports, metrics & export

Three program-grade features sit on top of the data layer. All three run
**fully on-device** — no network call, nothing uploaded. They read through the
provider contract; none reaches into `data/`.

**Screening report (PDF).** `ReportService` (`services/report_service.dart`)
renders a per-screening PDF: patient identity, the human-entered result in
plain language, the referral timeline, and a footer that states the app does
not diagnose. The patient detail screen's per-screening menu offers **Share
report** (system share sheet) and **Print report**. `buildScreeningReport` is
pure (bytes in, bytes out) and unit-tested; only share/print touch the
platform. PII leaves the device only if the health worker picks a destination.

**Program metrics.** `MetricsScreen` (opened from the home app bar) shows the
Phase-1 headline — **attendance rate**, the share of referred patients who
actually reached the clinic. `ProgramMetrics.from` folds every screening into
counts and rates. LOAD-BEARING: attendance counts `attended`/`treated` only —
`booked` is deliberately excluded (`hasReachedClinic`), because booking without
attending is the exact failure this product measures. `program_metrics_test`
pins that down.

**CSV export.** `ExportService.toCsv` builds an RFC-4180 CSV of the whole
caseload (patients joined with screenings); the metrics screen shares it via
the OS share sheet. Field devices hold the only copy of patient data, so this
is the manager's backup / analysis escape hatch.

New third-party packages back these: `pdf` + `printing` (report), `share_plus`
+ `path_provider` (CSV). Run `flutter pub get` after pulling this branch.

## Security, language & patient reminders

A second layer of program-grade features, all still **on-device / offline** and
still inside the "does not diagnose" line.

**App lock (PIN + biometric).** An optional PIN / biometric lock (Settings →
Security) gates the running app and re-engages when the app is backgrounded.
The PIN is stored only as a salted SHA-256 hash in the platform keystore
(`SecurityService`). Full setup — including the one Android `MainActivity`
change biometric needs — is in **docs/SECURITY.md**. (Encryption at rest is
deferred: its only library, `sqlcipher_flutter_libs`, is EOL and collides with
`sqlite3_flutter_libs`; it will return on the maintained `sqlite3` 3.x path.)

**Multi-language UI.** `lib/l10n/strings.dart` holds the app's strings as one
map per language (English, Hindi, Tamil) — no codegen, English fallback for any
missing key, and a test (`strings_test`) that fails CI if a translation is
missing. Switch language in Settings; `flutter_localizations` localises the
built-in Material widgets. The hi/ta translations are a starting point and
should be reviewed by a native speaker. The screening-entry form stays English
(the trained worker's tool); the patient-facing report and reminders localise.

**Patient reminders (WhatsApp / SMS).** From a patient record, the worker taps
to open WhatsApp or the SMS composer with a reminder pre-filled in the
patient's language (referral site included when known). Nothing is sent
automatically — the worker stays in control of the patient's data, and there is
no backend. This nudges *the patient*, directly targeting the attendance KPI.

**Metrics charts.** The metrics screen now draws a screening funnel (screened →
referable → referred → reached clinic → treated) and a 6-month trend, in pure
Flutter (no chart dependency).

New packages: `flutter_secure_storage`, `local_auth`, `crypto`,
`shared_preferences`, `flutter_localizations`. Run `flutter pub get` after
pulling this branch.

## Quality, hand-off & polish

- **Fundus image-quality gate** (`services/fundus_quality.dart`): scores every
  fundus photo on-device (brightness, focus via variance-of-Laplacian, retinal
  field coverage) and shows a good/fair/poor banner with the specific issues
  before a grade is entered — catching the #1 cause of ungradable screenings at
  capture time. Pure Dart on the `image` package; a *capture-quality* check
  only, never a clinical judgement.
- **QR referral hand-off**: every screening has a scannable referral QR (on
  screen and embedded in the PDF report) encoding the referral so a clinic can
  intake the patient without re-typing. `services/referral_pass.dart` builds the
  payload; `qr_flutter` renders on screen; the report uses the `pdf` package's
  own barcode.
- **Voice read-out (TTS)**: a Listen button speaks the result and next step in
  the patient's language for low-literacy field use (`services/tts_service.dart`).
- **Polish**: dark mode (Settings → Appearance), a first-run onboarding
  carousel, and a generated app icon + splash. Regenerate the icon/splash after
  `flutter pub get`:

  ```bash
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```

New packages: `qr_flutter`, `flutter_tts` (+ dev `flutter_launcher_icons`,
`flutter_native_splash`). The quality gate reuses the existing `image` dep.

## Things that are load-bearing

**`ReferralEvents` is append-only.** It is the evidence for the Phase 1
success claim (attendance lift vs. the partner's baseline, B06/B26). Never
update or delete a row. Corrections are new events with a note.

**`booked` is not an outcome.** `hasReachedClinic` deliberately excludes it —
the entire premise of the product is that people book appointments and then
don't attend.

**Migrations only add.** Field devices hold the only copy of patient data.
Bump `schemaVersion` and add an `onUpgrade` case; never drop a column holding
real data without a tested path.

**`referred → attended` skips booking on purpose.** Walk-ins are common at
vision centres. Confirm this against your pilot partner's actual workflow
(B05) — if their sites are appointment-only, remove it and make booking
mandatory.

**Keep the keystore out of the repo.** A leaked upload key cannot be rotated;
you permanently lose the ability to ship updates. `.gitignore` covers it —
don't override.

---

## What's still open on Person A's track

Covered here: A02–A12, plus A17's state machine and its tests.

Still to do: A13/A14 (wire full edit forms), A15/A16 (notifications and the
reminder engine), A18 (`url_launcher` service), A19 (health-worker home),
A20–A23 (release, signing, crash reporting).
