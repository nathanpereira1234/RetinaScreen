import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'patient_detail_screen.dart';

/// Program-wide activity log: every referral state change across all patients,
/// newest first. Built from the append-only ReferralEvents trail, so it doubles
/// as an audit view.
class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final activityAsync = ref.watch(recentActivityProvider);
    final fmt = DateFormat('dd MMM, HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(s.activityLog)),
      body: activityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(s.noActivityYet,
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              final from = e.event.fromStatus;
              final change = from == null
                  ? referralStatusLabel(s, e.event.toStatus)
                  : '${referralStatusLabel(s, from)} → '
                      '${referralStatusLabel(s, e.event.toStatus)}';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      e.patient.name.isNotEmpty
                          ? e.patient.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(e.patient.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$change · ${fmt.format(e.event.occurredAt)}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PatientDetailScreen(patientId: e.patient.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
