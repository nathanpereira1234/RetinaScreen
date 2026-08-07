import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/patient_list_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: RetinaScreenApp()));
}

class RetinaScreenApp extends StatelessWidget {
  const RetinaScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RetinaScreen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const PatientListScreen(),
    );
  }
}
