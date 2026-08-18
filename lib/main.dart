import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/patient_detail_screen.dart';
import 'services/crash_reporter.dart';
import 'theme/app_theme.dart';

/// Used to navigate from a tapped reminder without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  const crash = LoggingCrashReporter();

  // Route framework + async errors through the crash reporter (A23). No PII is
  // ever attached — see CrashReporter.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Load non-secret prefs before the first frame so language + lock state
      // are available synchronously.
      final prefs = PrefsService(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [prefsServiceProvider.overrideWithValue(prefs)],
      );

      FlutterError.onError = crash.recordFlutterError;
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        unawaited(crash.recordError(error, stack, fatal: true));
        return true;
      };

      await container.read(notificationServiceProvider).init();
      await container.read(reminderServiceProvider).syncAll();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const RetinaScreenApp(),
        ),
      );
    },
    (error, stack) => unawaited(crash.recordError(error, stack, fatal: true)),
  );
}

class RetinaScreenApp extends ConsumerStatefulWidget {
  const RetinaScreenApp({super.key});

  @override
  ConsumerState<RetinaScreenApp> createState() => _RetinaScreenAppState();
}

class _RetinaScreenAppState extends ConsumerState<RetinaScreenApp>
    with WidgetsBindingObserver {
  late final StreamSubscription<int> _reminderTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A tapped reminder carries a patientId; open that patient (A16).
    _reminderTaps =
        ref.read(notificationServiceProvider).onPatientSelected.listen(
              _openPatient,
            );
  }

  DateTime? _pausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prefs = ref.read(prefsServiceProvider);
    if (!prefs.lockEnabled) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // No grace period → lock immediately so the app-switcher preview is
      // hidden. With a grace period, we lock on resume instead.
      if (prefs.autoLockMinutes == 0) {
        ref.read(lockControllerProvider.notifier).lock();
      }
    } else if (state == AppLifecycleState.resumed) {
      final since = _pausedAt;
      final elapsed =
          since == null ? Duration.zero : DateTime.now().difference(since);
      if (elapsed >= Duration(minutes: prefs.autoLockMinutes)) {
        ref.read(lockControllerProvider.notifier).lock();
      }
      _pausedAt = null;
    }
  }

  void _openPatient(int patientId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailScreen(patientId: patientId),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTaps.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(localeProvider);
    final locked = ref.watch(lockControllerProvider);
    final onboarded = ref.watch(onboardingSeenProvider);
    final themeMode = ref.watch(themeModeProvider);
    final textScale = ref.watch(textScaleProvider);

    final Widget home = !onboarded
        ? const OnboardingScreen()
        : (locked ? const LockScreen() : const HomeScreen());

    return MaterialApp(
      title: 'RetinaScreen',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: Locale(language.code),
      supportedLocales: [
        for (final l in AppLanguage.values) Locale(l.code),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Apply the user's accessibility text scale on top of the OS setting.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1) * textScale,
            ),
          ),
          child: child!,
        );
      },
      home: home,
    );
  }
}
