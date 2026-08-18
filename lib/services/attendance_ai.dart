import 'dart:math' as math;

import '../data/database.dart';
import '../models/enums.dart';

/// On-device, **operational** ML for follow-up: how likely is a referred
/// patient to NOT reach the clinic, and how urgently should a worker chase
/// them. This is workflow prioritisation — it says nothing about disease, so it
/// stays well inside the "does not diagnose" line.
///
/// The model is a small logistic function over interpretable features. The
/// weights are documented priors (a sensible starting point), meant to be
/// replaced by coefficients fitted on a pilot's own attendance data — the shape
/// of the code doesn't change when you do. Pure and unit-tested
/// (`test/attendance_ai_test.dart`).
class AttendanceAi {
  const AttendanceAi();

  /// Probability (0–1) that this referral will NOT be attended. Higher = chase
  /// harder. Only meaningful for still-pending referrals (referred / booked).
  static double noShowProbability(Screening s, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final booked = s.referralStatus == ReferralStatus.booked;
    final daysSince = t.difference(s.screeningDate).inDays.clamp(0, 180);
    final overdue =
        s.nextReminderAt != null && s.nextReminderAt!.isBefore(t);
    final noReminder = s.nextReminderAt == null;

    // Logistic regression over normalised features (heuristic priors).
    var z = 0.15; // intercept
    z += booked ? -0.95 : 0.55; // an appointment lowers no-show risk
    z += (daysSince / 180) * 1.6; // staleness raises it
    z += overdue ? 1.1 : 0.0; // already past the reminder
    z += noReminder ? 0.5 : 0.0; // nobody scheduled a nudge
    if (s.result == ScreeningResult.ungradable) z += 0.3;

    return 1 / (1 + math.exp(-z));
  }

  /// A 0–1 outreach-priority score for ranking the day's follow-ups: combines
  /// no-show risk with clinical urgency (referable weighs more) and overdue-ness.
  static double outreachPriority(Screening s, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final risk = noShowProbability(s, now: t);
    final referable = s.result == ScreeningResult.referable ? 1.0 : 0.4;
    final overdue =
        (s.nextReminderAt != null && s.nextReminderAt!.isBefore(t)) ? 1.0 : 0.0;
    // Weighted blend, clamped to 0–1.
    return (0.55 * risk + 0.30 * referable + 0.15 * overdue).clamp(0.0, 1.0);
  }

  /// A coarse label for the UI badge.
  static OutreachBand band(double priority) {
    if (priority >= 0.66) return OutreachBand.high;
    if (priority >= 0.4) return OutreachBand.medium;
    return OutreachBand.low;
  }

  /// Suggest a follow-up reminder date based on the result and referral state:
  /// referable cases are chased sooner, routine ones later. A sensible default
  /// the worker can accept or override.
  static DateTime suggestReminderDate(
    ScreeningResult result,
    ReferralStatus status, {
    DateTime? from,
  }) {
    final base = from ?? DateTime.now();
    final days = switch (result) {
      ScreeningResult.referable =>
        status == ReferralStatus.booked ? 7 : 14,
      ScreeningResult.ungradable => 7,
      ScreeningResult.notReferable => 365, // annual re-screen
    };
    return DateTime(base.year, base.month, base.day + days, 9);
  }
}

enum OutreachBand { low, medium, high }
