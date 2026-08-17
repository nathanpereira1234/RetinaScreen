import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'metrics_screen.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';
import 'patient_list_screen.dart';

/// Health-worker home / dashboard (A19): a live pending-referral count, the
/// patients due for follow-up, and recently screened patients — the daily view.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount =
        ref.watch(pendingReferralCountProvider).valueOrNull ?? 0;
    final dueAsync = ref.watch(dueFollowUpsProvider);
    final recentAsync = ref.watch(recentScreeningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RetinaScreen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Program metrics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MetricsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'All patients',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PatientListScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _PendingSummary(count: pendingCount),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle('Due for follow-up'),
          const SizedBox(height: AppSpacing.sm),
          dueAsync.when(
            loading: () => const _Loading(),
            error: (e, _) => Text('Error: $e'),
            data: (items) => items.isEmpty
                ? const _EmptyLine('No pending follow-ups.')
                : Column(
                    children: [
                      for (final entry in items)
                        _DashboardTile(
                          entry: entry,
                          subtitle: _followUpSubtitle(entry),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle('Recently screened'),
          const SizedBox(height: AppSpacing.sm),
          recentAsync.when(
            loading: () => const _Loading(),
            error: (e, _) => Text('Error: $e'),
            data: (items) => items.isEmpty
                ? const _EmptyLine('No screenings recorded yet.')
                : Column(
                    children: [
                      for (final entry in items)
                        _DashboardTile(
                          entry: entry,
                          subtitle: _recentSubtitle(entry),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PatientFormScreen()),
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add patient'),
      ),
    );
  }

  String _followUpSubtitle(PatientScreening e) {
    final status = e.screening.referralStatus.name;
    final due = e.screening.nextReminderAt;
    return due == null ? status : '$status · due ${_formatDate(due)}';
  }

  String _recentSubtitle(PatientScreening e) =>
      '${_resultText(e.screening.result)} · ${_formatDate(e.screening.screeningDate)}';
}

class _PendingSummary extends StatelessWidget {
  const _PendingSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: count > 0 ? AppColors.pending : AppColors.reached,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'referrals awaiting follow-up',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({required this.entry, required this.subtitle});

  final PatientScreening entry;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            entry.patient.name.isNotEmpty
                ? entry.patient.name[0].toUpperCase()
                : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          entry.patient.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailScreen(patientId: entry.patient.id),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

String _resultText(ScreeningResult r) => switch (r) {
      ScreeningResult.referable => 'Referable',
      ScreeningResult.notReferable => 'Not referable',
      ScreeningResult.ungradable => 'Ungradable',
    };

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
