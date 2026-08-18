import 'dart:math' as math;

import '../data/database.dart';
import '../models/enums.dart';

/// Flags statistically unusual sites so a program manager notices problems
/// early — e.g. a vision centre whose ungradable rate is way above the rest
/// (camera/technique issue) or whose attendance has collapsed. Operational,
/// non-clinical. Pure and unit-tested (`test/anomaly_detector_test.dart`).
enum AnomalyKind { highUngradable, lowAttendance }

class SiteAnomaly {
  const SiteAnomaly({
    required this.site,
    required this.kind,
    required this.value,
    required this.cohortMean,
  });

  final String site;
  final AnomalyKind kind;

  /// The site's rate (0–1) for this metric.
  final double value;

  /// The cohort mean (0–1) it's being compared against.
  final double cohortMean;
}

class AnomalyDetector {
  const AnomalyDetector();

  /// Sites need at least this many screenings before we judge them — small
  /// samples produce noisy rates.
  static const int minSample = 5;

  /// A site is anomalous when its rate is more than [_k] standard deviations
  /// from the cohort mean (in the bad direction).
  static const double _k = 1.5;

  static List<SiteAnomaly> detect(List<Screening> screenings) {
    // Group by site, counting screenings, ungradable, referred and reached.
    final byS = <String, List<int>>{}; // [screened, ungradable, referred, reached]
    for (final s in screenings) {
      final site = (s.referralSite == null || s.referralSite!.isEmpty)
          ? 'Unassigned'
          : s.referralSite!;
      final a = byS.putIfAbsent(site, () => [0, 0, 0, 0]);
      a[0]++;
      if (s.result == ScreeningResult.ungradable) a[1]++;
      if (s.referralStatus != ReferralStatus.none) a[2]++;
      if (s.referralStatus.hasReachedClinic) a[3]++;
    }

    final eligible =
        byS.entries.where((e) => e.value[0] >= minSample).toList();
    if (eligible.length < 3) return const []; // too few sites to compare

    final ungradable = {
      for (final e in eligible) e.key: e.value[1] / e.value[0],
    };
    final attendance = {
      for (final e in eligible)
        if (e.value[2] > 0) e.key: e.value[3] / e.value[2],
    };

    final anomalies = <SiteAnomaly>[];

    final (uMean, uStd) = _stats(ungradable.values);
    for (final entry in ungradable.entries) {
      if (uStd > 0 && entry.value > uMean + _k * uStd) {
        anomalies.add(SiteAnomaly(
          site: entry.key,
          kind: AnomalyKind.highUngradable,
          value: entry.value,
          cohortMean: uMean,
        ));
      }
    }

    final (aMean, aStd) = _stats(attendance.values);
    for (final entry in attendance.entries) {
      if (aStd > 0 && entry.value < aMean - _k * aStd) {
        anomalies.add(SiteAnomaly(
          site: entry.key,
          kind: AnomalyKind.lowAttendance,
          value: entry.value,
          cohortMean: aMean,
        ));
      }
    }
    return anomalies;
  }

  static (double, double) _stats(Iterable<double> xs) {
    final list = xs.toList();
    if (list.isEmpty) return (0, 0);
    final mean = list.reduce((a, b) => a + b) / list.length;
    final variance =
        list.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            list.length;
    return (mean, math.sqrt(variance));
  }
}
