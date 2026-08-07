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
