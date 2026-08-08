# Phase 1 — Android native setup

The repo tracks hand-written source only; `android/` is generated at bootstrap
(`flutter create`, see the top-level README). A few features need entries in
`android/app/src/main/AndroidManifest.xml` that the generated manifest does not
include. Add these after `flutter create`.

## Notifications + reminders (A15 / A16)

Inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Inside `<application>` (registers `flutter_local_notifications` receivers so
scheduled reminders survive a reboot):

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

### Core library desugaring (required)

`flutter_local_notifications` needs Java 8+ API desugaring. In
`android/app/build.gradle.kts`, enable it in `compileOptions` and add the
desugar dependency:

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

(Groovy `build.gradle`: `coreLibraryDesugaringEnabled true` and
`coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'`.) Without it
the build fails with `checkDebugAarMetadata … requires core library desugaring`.

### Why no exact-alarm permission

`NotificationService.schedule` uses `AndroidScheduleMode.inexactAllowWhileIdle`,
so the app does NOT need `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` (which Google
Play scrutinises heavily). Follow-up reminders for eye-clinic visits do not need
to-the-minute precision; the OS may batch them by a few minutes. If a future
requirement truly needs exact timing, switch the mode and add the permission
plus a Play Console justification — do not do it by default.

## Launching maps + dialer (A18)

Android 11+ requires declaring the intents the app queries. Inside `<manifest>`
(a sibling of `<application>`):

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/>
  </intent>
  <intent>
    <action android:name="android.intent.action.DIAL"/>
    <data android:scheme="tel"/>
  </intent>
</queries>
```

Without this, `url_launcher` reports the maps / dialer intents as unavailable on
Android 11+.

## Verifying A15

Call `NotificationService.showTest()` (e.g. from a temporary debug button) after
granting the notification permission; a heads-up notification on the
"Follow-up reminders" channel confirms the setup.
