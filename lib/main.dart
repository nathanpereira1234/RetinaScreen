import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/patient_detail_screen.dart';
import 'theme/app_theme.dart';

/// Used to navigate from a tapped reminder without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // One container shared between the pre-frame setup and the widget tree.
  final container = ProviderContainer();
  final crash = container.read(crashReporterProvider);

  // Route framework + async errors through the crash reporter (A23). No PII is
  // ever attached — see CrashReporter.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
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

class _RetinaScreenAppState extends ConsumerState<RetinaScreenApp> {
  late final StreamSubscription<int> _reminderTaps;

  @override
  void initState() {
    super.initState();
    // A tapped reminder carries a patientId; open that patient (A16).
    _reminderTaps =
        ref.read(notificationServiceProvider).onPatientSelected.listen(
              _openPatient,
            );
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
    _reminderTaps.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RetinaScreen',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
