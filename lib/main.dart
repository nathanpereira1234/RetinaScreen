import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'screens/patient_detail_screen.dart';
import 'screens/patient_list_screen.dart';
import 'theme/app_theme.dart';

/// Used to navigate from a tapped reminder without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Share one ProviderContainer between the pre-frame setup and the widget
  // tree so the services initialised here are the same instances the UI uses.
  final container = ProviderContainer();
  await container.read(notificationServiceProvider).init();
  await container.read(reminderServiceProvider).syncAll();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RetinaScreenApp(),
    ),
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
      home: const PatientListScreen(),
    );
  }
}
