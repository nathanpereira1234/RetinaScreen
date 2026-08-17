# Security — app lock (PIN + biometric)

RetinaScreen keeps patient data on the device. The current build protects
access to it with an **app lock**; it is fully offline.

> **Encryption at rest is deferred.** It previously used SQLCipher via
> `sqlcipher_flutter_libs`, but that package is now **EOL** (`0.7.0+eol`, "no
> longer does anything") and its old Android module collides with
> `sqlite3_flutter_libs` on a shared namespace, which breaks the build. Rather
> than ship a deprecated dependency, at-rest encryption is parked until it can
> be reintroduced on the maintained `sqlite3` 3.x path. The app lock below is
> the active security layer.

## App lock (PIN + biometric)

Turn it on in **Settings → Security → App lock**. A PIN is always available;
biometric is offered when the device supports it. The lock gates the running
app (against shoulder-surfing / a lost unlocked phone) and re-engages whenever
the app leaves the foreground.

- The PIN is stored only as a salted SHA-256 hash (`SecurityService`), never in
  plaintext, and verified in length-constant time. The hash lives in the
  platform keystore/keychain via `flutter_secure_storage`.

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
button is hidden). The lock is **off by default**, so neither change is needed
just to build and run the app.
