/// Program-level screening metrics — the numbers that make the Phase-1 success
/// claim (attendance lift vs. the partner baseline, B06/B26).
///
/// This is a *pure* view model: [ProgramMetrics.from] folds a list of
/// screenings into counts and rates with no Flutter, no async, and no side
/// effects, so it is unit-tested in isolation
/// (`test/program_metrics_test.dart`). The screens read it through a provider;
/// they never compute a rate themselves.
///
/// LOAD-BEARING: the attendance rate deliberately counts only patients who
/// *reached the clinic* ([ReferralStatus.hasReachedClinic]) — `booked` is not
/// attendance. Booking-but-not-attending is precisely the failure this product
/// measures, so it must never inflate the headline number.
library;

import '../data/database.dart';
import 'enums.dart';

class ProgramMetrics {
  const ProgramMetrics({
    required this.totalPatients,
    required this.totalScreenings,
    required this.referableCount,
    required this.ungradableCount,
    required this.referredCount,
    required this.reachedClinicCount,
    required this.treatedCount,
    required this.pendingCount,
  });

  /// Everyone registered in the program — including patients not yet screened.
  final int totalPatients;

  /// Screening events recorded across all patients.
  final int totalScreenings;

  /// Screenings a human graded as [ScreeningResult.referable].
  final int referableCount;

  /// Screenings a human could not grade ([ScreeningResult.ungradable]).
  final int ungradableCount;

  /// Screenings that entered the referral pathway at all
  /// (referralStatus != [ReferralStatus.none]). The denominator for attendance.
  final int referredCount;

  /// Screenings whose patient physically reached the clinic
  /// (attended or treated). Excludes `booked` on purpose.
  final int reachedClinicCount;

  /// Screenings that reached treatment.
  final int treatedCount;

  /// Referred-or-booked, not yet attended — the follow-ups still to chase.
  final int pendingCount;

  /// Fold screenings into metrics. Pure; safe to call on every rebuild.
  factory ProgramMetrics.from({
    required int totalPatients,
    required List<Screening> screenings,
  }) {
    var referable = 0;
    var ungradable = 0;
    var referred = 0;
    var reached = 0;
    var treated = 0;
    var pending = 0;

    for (final s in screenings) {
      switch (s.result) {
        case ScreeningResult.referable:
          referable++;
        case ScreeningResult.ungradable:
          ungradable++;
        case ScreeningResult.notReferable:
          // Counted only in the totals; no dedicated tally.
          break;
      }

      final status = s.referralStatus;
      if (status != ReferralStatus.none) referred++;
      if (status.hasReachedClinic) reached++;
      if (status == ReferralStatus.treated) treated++;
      if (status == ReferralStatus.referred ||
          status == ReferralStatus.booked) {
        pending++;
      }
    }

    return ProgramMetrics(
      totalPatients: totalPatients,
      totalScreenings: screenings.length,
      referableCount: referable,
      ungradableCount: ungradable,
      referredCount: referred,
      reachedClinicCount: reached,
      treatedCount: treated,
      pendingCount: pending,
    );
  }

  /// Zero-state, for a program with no data yet.
  static const empty = ProgramMetrics(
    totalPatients: 0,
    totalScreenings: 0,
    referableCount: 0,
    ungradableCount: 0,
    referredCount: 0,
    reachedClinicCount: 0,
    treatedCount: 0,
    pendingCount: 0,
  );

  /// Share of screenings that entered the referral pathway, 0–1.
  double get referralRate =>
      totalScreenings == 0 ? 0 : referredCount / totalScreenings;

  /// Share of screenings a human could not grade, 0–1. A quality signal on the
  /// imaging step — high ungradable means re-train / re-image, not reassure.
  double get ungradableRate =>
      totalScreenings == 0 ? 0 : ungradableCount / totalScreenings;

  /// THE headline: of everyone referred, the share who actually reached the
  /// clinic. `booked` does NOT count. 0 when nobody has been referred yet.
  double get attendanceRate =>
      referredCount == 0 ? 0 : reachedClinicCount / referredCount;

  /// Of everyone who reached the clinic, the share who received treatment.
  double get treatmentRate =>
      reachedClinicCount == 0 ? 0 : treatedCount / reachedClinicCount;
}
