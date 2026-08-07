/// Domain enums and the referral state machine (A17).
///
/// This file has no Flutter or Drift dependency on purpose: the state machine
/// is pure logic and is unit-tested in isolation
/// (`test/referral_state_machine_test.dart`).
library;

/// The clinical finding a *human* entered for a screening.
///
/// The app never computes this — a health worker or clinician records it. That
/// line ("we explain and remind, we do not diagnose") is what keeps Phase 1
/// outside SaMD. Do not add a value that the app would derive itself.
enum ScreeningResult {
  /// Findings warrant an ophthalmologist visit.
  referable,

  /// No referable disease found on this screen.
  notReferable,

  /// Image quality too poor to grade — re-screen, do not reassure.
  ungradable,
}

/// Where a referred patient is along the follow-up path.
///
/// The whole product exists because people are *referred* and then never
/// *attend*. The transitions below encode the only legal moves; anything else
/// throws [InvalidReferralTransition].
enum ReferralStatus {
  /// No referral needed / not yet referred.
  none,

  /// Told to see an ophthalmologist.
  referred,

  /// Appointment booked. NOTE: booking is not attending — see [hasReachedClinic].
  booked,

  /// Physically showed up at the clinic. This is the outcome that matters.
  attended,

  /// Received treatment after attending.
  treated;

  /// The statuses this status may legally move to.
  ///
  /// `referred -> attended` intentionally skips `booked`: walk-ins are common
  /// at vision centres. If a pilot partner is appointment-only (B05), remove
  /// that edge and make booking mandatory.
  Set<ReferralStatus> get nextStates {
    switch (this) {
      case ReferralStatus.none:
        return const {ReferralStatus.referred};
      case ReferralStatus.referred:
        return const {ReferralStatus.booked, ReferralStatus.attended};
      case ReferralStatus.booked:
        return const {ReferralStatus.attended};
      case ReferralStatus.attended:
        return const {ReferralStatus.treated};
      case ReferralStatus.treated:
        return const {};
    }
  }

  /// Whether [to] is a legal next status from here.
  bool canTransitionTo(ReferralStatus to) => nextStates.contains(to);

  /// True once the patient has physically reached the clinic.
  ///
  /// Deliberately EXCLUDES [booked]: a booked-but-not-attended appointment is
  /// precisely the failure this product measures. Use this — not `>= booked` —
  /// when reporting attendance lift against the partner baseline (B06/B26).
  bool get hasReachedClinic =>
      this == ReferralStatus.attended || this == ReferralStatus.treated;
}

/// Thrown when code attempts a referral move that the state machine forbids.
///
/// Screens should catch this and surface `from.nextStates` to the user rather
/// than swallowing it — an illegal transition is a real workflow bug.
class InvalidReferralTransition implements Exception {
  InvalidReferralTransition(this.from, this.to);

  final ReferralStatus from;
  final ReferralStatus to;

  @override
  String toString() =>
      'InvalidReferralTransition: cannot move from ${from.name} to ${to.name}. '
      'Allowed next: ${from.nextStates.map((s) => s.name).join(', ')}.';
}
