import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// Program dashboard: the numbers behind the Phase-1 success claim.
///
/// The headline is the attendance rate — of everyone referred, how many
/// actually reached the clinic. `booked` does NOT count as reaching the clinic
/// (that is the exact failure this product measures), so this screen never
/// shows a rate that treats a booking as a win.
class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(programMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program metrics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
            onPressed: () => _export(context, ref),
          ),
        ],
      ),
      body: metricsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load metrics:\n$e')),
        data: (m) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _Headline(metrics: m),
            const SizedBox(height: AppSpacing.md),
            _StatGrid(metrics: m),
            const SizedBox(height: AppSpacing.md),
            _RateRow(
              label: 'Referral rate',
              caption: 'screenings that entered the referral pathway',
              rate: m.referralRate,
              color: AppColors.pending,
            ),
            _RateRow(
              label: 'Ungradable rate',
              caption: 'images a human could not grade — an imaging-quality '
                  'signal',
              rate: m.ungradableRate,
              color: AppColors.ungradable,
            ),
            _RateRow(
              label: 'Treatment rate',
              caption: 'of those who reached the clinic, share treated',
              rate: m.treatmentRate,
              color: AppColors.reached,
            ),
            const SizedBox(height: AppSpacing.md),
            const _AttendanceNote(),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final rows =
        await ref.read(patientRepositoryProvider).allScreeningsForExport();
    final shared = await ref.read(exportServiceProvider).shareCsv(rows);
    if (!shared) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export yet.')),
      );
    }
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.metrics});

  final ProgramMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final pct = (metrics.attendanceRate * 100).round();
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$pct%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'of referred patients reached the clinic',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${metrics.reachedClinicCount} of ${metrics.referredCount} '
              'referrals · booking alone does not count',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.metrics});

  final ProgramMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String)>[
      ('Patients', '${metrics.totalPatients}'),
      ('Screenings', '${metrics.totalScreenings}'),
      ('Referable', '${metrics.referableCount}'),
      ('Pending follow-up', '${metrics.pendingCount}'),
      ('Reached clinic', '${metrics.reachedClinicCount}'),
      ('Treated', '${metrics.treatedCount}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.4,
      children: [
        for (final (label, value) in tiles) _StatTile(label: label, value: value),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.label,
    required this.caption,
    required this.rate,
    required this.color,
  });

  final String label;
  final String caption;
  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('${(rate * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: LinearProgressIndicator(
              value: rate.clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(caption, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AttendanceNote extends StatelessWidget {
  const _AttendanceNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.background,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Attendance counts only patients who physically reached the clinic '
          '(attended or treated). A booked-but-not-attended appointment is the '
          'failure this program measures, so it is never counted as success.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
