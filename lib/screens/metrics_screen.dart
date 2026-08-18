import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// Program dashboard: the numbers behind the Phase-1 success claim, plus a
/// screening funnel and a monthly trend.
///
/// The headline is the attendance rate — of everyone referred, how many
/// actually reached the clinic. `booked` does NOT count as reaching the clinic
/// (that is the exact failure this product measures), so this screen never
/// shows a rate that treats a booking as a win.
class MetricsScreen extends ConsumerStatefulWidget {
  const MetricsScreen({super.key});

  @override
  ConsumerState<MetricsScreen> createState() => _MetricsScreenState();
}

enum _Range { all, d90, d30 }

class _MetricsScreenState extends ConsumerState<MetricsScreen> {
  _Range _range = _Range.all;

  bool _inRange(Screening s) => switch (_range) {
        _Range.all => true,
        _Range.d90 => s.screeningDate
            .isAfter(DateTime.now().subtract(const Duration(days: 90))),
        _Range.d30 => s.screeningDate
            .isAfter(DateTime.now().subtract(const Duration(days: 30))),
      };

  String _rangeLabel(AppStrings s) => switch (_range) {
        _Range.all => s.rangeAll,
        _Range.d90 => s.range90,
        _Range.d30 => s.range30,
      };

  ProgramMetrics _metricsFor(List<Screening> filtered, List<Patient> patients) {
    final total = _range == _Range.all
        ? patients.length
        : filtered.map((e) => e.patientId).toSet().length;
    return ProgramMetrics.from(totalPatients: total, screenings: filtered);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final screeningsAsync = ref.watch(allScreeningsProvider);
    final patients =
        ref.watch(patientListProvider).valueOrNull ?? const <Patient>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(s.programMetrics),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: s.programReport,
            onPressed: () => _exportPdf(patients),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: s.exportCsv,
            onPressed: () => _exportCsv(context),
          ),
        ],
      ),
      body: screeningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load metrics:\n$e')),
        data: (all) {
          final filtered = all.where(_inRange).toList();
          final m = _metricsFor(filtered, patients);
          final sites = ProgramMetrics.siteStats(filtered);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _RangeSelector(
                range: _range,
                strings: s,
                onChanged: (r) => setState(() => _range = r),
              ),
              const SizedBox(height: AppSpacing.md),
              _Headline(metrics: m),
              const SizedBox(height: AppSpacing.md),
              _StatGrid(metrics: m),
              const SizedBox(height: AppSpacing.lg),
              _CardSection(
                title: s.screeningFunnel,
                child: _FunnelChart(metrics: m, strings: s),
              ),
              const SizedBox(height: AppSpacing.md),
              _CardSection(
                title: s.attendanceOverTime,
                child: _TrendChart(months: _monthlySeries(filtered)),
              ),
              const SizedBox(height: AppSpacing.md),
              _RateRow(
                label: s.referralRate,
                rate: m.referralRate,
                color: AppColors.pending,
              ),
              _RateRow(
                label: s.ungradableRate,
                rate: m.ungradableRate,
                color: AppColors.ungradable,
              ),
              _RateRow(
                label: s.treatmentRate,
                rate: m.treatmentRate,
                color: AppColors.reached,
              ),
              if (sites.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _CardSection(
                  title: s.bySite,
                  child: _SiteBreakdown(sites: sites, strings: s),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final s = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final rows =
        await ref.read(patientRepositoryProvider).allScreeningsForExport();
    final shared = await ref.read(exportServiceProvider).shareCsv(rows);
    if (!shared) {
      messenger.showSnackBar(SnackBar(content: Text(s.nothingToExport)));
    }
  }

  Future<void> _exportPdf(List<Patient> patients) async {
    final s = ref.read(stringsProvider);
    final all =
        ref.read(allScreeningsProvider).valueOrNull ?? const <Screening>[];
    final filtered = all.where(_inRange).toList();
    await ref.read(reportServiceProvider).shareProgramSummary(
          metrics: _metricsFor(filtered, patients),
          sites: ProgramMetrics.siteStats(filtered),
          rangeLabel: _rangeLabel(s),
        );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.range,
    required this.strings,
    required this.onChanged,
  });

  final _Range range;
  final AppStrings strings;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Range>(
      segments: [
        ButtonSegment(value: _Range.all, label: Text(strings.rangeAll)),
        ButtonSegment(value: _Range.d90, label: Text(strings.range90)),
        ButtonSegment(value: _Range.d30, label: Text(strings.range30)),
      ],
      selected: {range},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _SiteBreakdown extends StatelessWidget {
  const _SiteBreakdown({required this.sites, required this.strings});

  final List<SiteStat> sites;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final st in sites)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    st.site,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${st.reached}/${st.referred} · '
                  '${(st.attendanceRate * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The last 6 calendar months of screening counts (and reached-clinic counts),
/// oldest first. Pure — folds the screening list into monthly buckets.
List<MonthBucket> _monthlySeries(List<Screening> screenings) {
  final now = DateTime.now();
  final buckets = <String, MonthBucket>{};
  final order = <String>[];
  for (var i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i);
    final key = '${d.year}-${d.month}';
    order.add(key);
    buckets[key] = MonthBucket(label: DateFormat('MMM').format(d));
  }
  for (final sc in screenings) {
    final key = '${sc.screeningDate.year}-${sc.screeningDate.month}';
    final bucket = buckets[key];
    if (bucket == null) continue; // outside the 6-month window
    bucket.screened++;
    if (sc.referralStatus.hasReachedClinic) bucket.reached++;
  }
  return [for (final k in order) buckets[k]!];
}

/// One month's counts for the trend chart.
class MonthBucket {
  MonthBucket({required this.label});
  final String label;
  int screened = 0;
  int reached = 0;
}

class _Headline extends ConsumerWidget {
  const _Headline({required this.metrics});

  final ProgramMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
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
              s.attendanceHeadline,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${metrics.reachedClinicCount} / ${metrics.referredCount}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends ConsumerWidget {
  const _StatGrid({required this.metrics});

  final ProgramMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final tiles = <(String, String)>[
      (s.patients, '${metrics.totalPatients}'),
      (s.screenings, '${metrics.totalScreenings}'),
      (s.referable, '${metrics.referableCount}'),
      (s.dueForFollowUp, '${metrics.pendingCount}'),
      (s.attended, '${metrics.reachedClinicCount}'),
      (s.treated, '${metrics.treatedCount}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.4,
      children: [
        for (final (label, value) in tiles)
          _StatTile(label: label, value: value),
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

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Horizontal proportional bars: screened → referable → referred → reached →
/// treated. Each bar's width is relative to the largest stage.
class _FunnelChart extends StatelessWidget {
  const _FunnelChart({required this.metrics, required this.strings});

  final ProgramMetrics metrics;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final stages = <(String, int, Color)>[
      (strings.screenings, metrics.totalScreenings, AppColors.primary),
      (strings.referable, metrics.referableCount, AppColors.pending),
      (strings.referred, metrics.referredCount, AppColors.ungradable),
      (strings.attended, metrics.reachedClinicCount, AppColors.reached),
      (strings.treated, metrics.treatedCount, AppColors.notReferable),
    ];
    final max = stages.fold<int>(0, (m, s) => s.$2 > m ? s.$2 : m);
    return Column(
      children: [
        for (final (label, value, color) in stages)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final frac = max == 0 ? 0.0 : value / max;
                      return Stack(
                        children: [
                          Container(
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(AppSpacing.xs)),
                            ),
                          ),
                          Container(
                            height: 22,
                            width: (c.maxWidth * frac).clamp(0, c.maxWidth),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(AppSpacing.xs),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 32,
                  child: Text('$value', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Monthly vertical bars: total screenings, with the reached-clinic portion
/// shaded darker.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.months});

  final List<MonthBucket> months;

  @override
  Widget build(BuildContext context) {
    final max = months.fold<int>(0, (m, b) => b.screened > m ? b.screened : m);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in months)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${b.screened}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 2),
                    _Bar(
                      total: b.screened,
                      reached: b.reached,
                      max: max,
                    ),
                    const SizedBox(height: 4),
                    Text(b.label,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.total, required this.reached, required this.max});

  final int total;
  final int reached;
  final int max;

  @override
  Widget build(BuildContext context) {
    const fullHeight = 90.0;
    final totalH = max == 0 ? 0.0 : (total / max) * fullHeight;
    final reachedH = total == 0 ? 0.0 : (reached / total) * totalH;
    return Container(
      height: fullHeight,
      alignment: Alignment.bottomCenter,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: totalH,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          Container(
            height: reachedH,
            decoration: const BoxDecoration(
              color: AppColors.reached,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.label,
    required this.rate,
    required this.color,
  });

  final String label;
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
        ],
      ),
    );
  }
}
