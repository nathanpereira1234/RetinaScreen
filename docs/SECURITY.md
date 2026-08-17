# Security — encryption at rest + app lock

RetinaScreen keeps patient data on the device. Two independent layers protect
it, both fully offline.

## 1. Encryption at rest (SQLCipher)

The SQLite database is opened through **SQLCipher** (`sqlcipher_flutter_libs`),
keyed with a per-install random 256-bit passphrase stored in the platform
keystore/keychain via `flutter_secure_storage`. A database file copied off a
lost or stolen device is unreadable without that keystore entry.

- Key management: `SecurityService.databasePassphrase()` creates the key on
  first launch and returns it thereafter. It is **never** derived from the PIN,
  so unlocking is instant and a forgotten PIN never loses data.
- Wiring: `AppDatabase.encrypted(...)` opens the file with
  `PRAGMA key = ...` and asserts `PRAGMA cipher_version` is non-empty — if the
  linked SQLite is *not* SQLCipher the app fails loudly instead of silently
  writing plaintext.

No extra Android setup is required for SQLCipher — the native library ships
with `sqlcipher_flutter_libs` and is selected at open time.

> **Upgrading an existing plaintext install.** Encryption is applied to the
> database file created on first launch. A database written by an earlier,
> unencrypted build is not read by the encrypted opener. This is safe for a
> pre-pilot build (no field data yet). If you already have field data, migrate
> it with SQLCipher's `sqlcipher_export` before shipping this change.

## 2. App lock (PIN + biometric)

Turn it on in **Settings → Security → App lock**. A PIN is always available;
biometric is offered when the device supports it. The lock gates the running
app (against shoulder-surfing / a lost unlocked phone) and re-engages whenever
the app leaves the foreground. It does **not** hold the database key.

- The PIN is stored only as a salted SHA-256 hash (`SecurityService`), never in
  plaintext, and verified in length-constant time.

### Required Android config for biometric

`local_auth` needs the host activity to be a `FlutterFragmentActivity` and the
biometric permission declared. After `flutter create` generates `android/`:

1. **`android/app/src/main/kotlin/.../MainActivity.kt`** — change the base
   class:

   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity : FlutterFragmentActivity()
   ```

2. **`android/app/src/main/AndroidManifest.xml`** — add inside `<manifest>`:

   ```xml
   <uses-permission android:name="android.permission.USE_BIOMETRIC" />
   ```

If you skip this, the PIN still works; biometric simply reports unavailable
(the code degrades gracefully — `canUseBiometric()` returns false and the
button is hidden).
