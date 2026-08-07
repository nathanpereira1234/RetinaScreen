# Phase 1 — release runbook (A20–A23)

These steps touch the generated `android/` folder, a secret keystore, and the
Play Console — none of which live in this repo. Run them against your local
bootstrap (`flutter create`, see the top-level README).

## A20 — App icon, name, package id

- **applicationId** (permanent once published): set in
  `android/app/build.gradle` → `defaultConfig.applicationId`, e.g.
  `com.retinascreen.app`. Choose carefully — it cannot change after launch.
- **App name**: `android/app/src/main/AndroidManifest.xml` →
  `android:label="RetinaScreen"`.
- **Launcher icon**: add `flutter_launcher_icons` as a dev dependency, drop a
  1024x1024 PNG at `assets/icon/icon.png`, configure it in `pubspec.yaml`, then
  `dart run flutter_launcher_icons`.

  ```yaml
  dev_dependencies:
    flutter_launcher_icons: ^0.14.1

  flutter_launcher_icons:
    android: true
    ios: false
    image_path: "assets/icon/icon.png"
    adaptive_icon_background: "#00695C"
    adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  ```

**DoD:** the app installs on a device showing the correct name and icon.

## A21 — Signing config + upload keystore

A leaked or lost upload key is unrecoverable — you permanently lose the ability
to ship updates. The keystore and its passwords must NEVER be committed
(`.gitignore` already covers `*.jks`, `*.keystore`, `key.properties`).

1. Generate the upload keystore (store it in a password manager / secure vault,
   not the repo):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (gitignored) pointing at it:

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```

3. Wire `android/app/build.gradle` to read it and use it for the `release`
   build type (load `key.properties` into a `Properties` object above
   `android {}`, add a `signingConfigs.release` from those values, and set
   `buildTypes.release.signingConfig signingConfigs.release`).

**DoD:** `flutter build appbundle` produces a signed release AAB.

## A22 — Build the release AAB + internal testing

```bash
flutter build appbundle --release
# output: build/app/outputs/bundle/release/app-release.aab
```

Upload to the Play Console **Internal testing** track first — never straight to
production for a health app. Promote internal → closed → open → production as
confidence grows. (Depends on B18 — the store listing / data-safety form.)

**DoD:** internal testers can install the build from Play.

## A23 — Crash reporting dashboard

The app already routes framework and async errors through `CrashReporter`
(`lib/services/crash_reporter.dart`), wired in `main` via `FlutterError.onError`,
`PlatformDispatcher.onError` and `runZonedGuarded`. Phase 1 ships
`LoggingCrashReporter` (no third-party SDK, no PII).

To get a real dashboard, add a backend implementation and point
`crashReporterProvider` at it — no call sites change. With Sentry:

```dart
class SentryCrashReporter extends CrashReporter {
  @override
  Future<void> recordError(Object error, StackTrace? stack,
          {bool fatal = false, String? context}) =>
      Sentry.captureException(error, stackTrace: stack);
  // ...recordFlutterError delegates likewise
}
```

Initialise with the DSN passed at build time (`--dart-define=SENTRY_DSN=...`),
and set `options.sendDefaultPii = false`. Keep the no-PII rule: never attach
patient names, phone numbers, or screening data to an event.

**DoD:** a forced test error (throw inside a button handler) appears in the
dashboard.
