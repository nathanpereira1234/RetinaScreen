/// THE CONTRACT (A11).
///
/// Person A owns this file; Person B's screens import *only* this. Screens
/// never import `data/database.dart` directly — if a screen needs data this
/// file does not expose, that is a request to Person A at the daily sync.
///
/// Data flows one way: Drift -> provider -> widget. Reads are streams, so the
/// UI refreshes itself after any write.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/enums.dart';
import '../services/launcher_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';

// Re-export the row types and domain enums so screens get them from this one
// import and never reach into `data/`.
export '../data/database.dart' show Patient, Screening, ReferralEvent;
export '../models/enums.dart';
export '../services/launcher_service.dart' show LauncherService;
export '../services/notification_service.dart' show NotificationService;
export '../services/reminder_service.dart' show ReminderService;

/// The single database instance for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ---------------------------------------------------------------------------
// Reads — all streams.
// ---------------------------------------------------------------------------

/// `List<Patient>`, newest first.
final patientListProvider = StreamProvider<List<Patient>>((ref) {
  return ref.watch(databaseProvider).watchPatients();
});

/// One `Patient?` by id.
final patientProvider =
    StreamProvider.family<Patient?, int>((ref, id) {
  return ref.watch(databaseProvider).watchPatient(id);
});

/// A patient's screening history.
final screeningsProvider =
    StreamProvider.family<List<Screening>, int>((ref, patientId) {
  return ref.watch(databaseProvider).watchScreenings(patientId);
});

/// Referred-or-booked, not yet attended.
final pendingReferralsProvider = StreamProvider<List<Screening>>((ref) {
  return ref.watch(databaseProvider).watchPendingReferrals();
});

/// Count for the home badge.
final pendingReferralCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchPendingReferralCount();
});

/// Append-only audit trail for the timeline UI.
final referralHistoryProvider =
    StreamProvider.family<List<ReferralEvent>, int>((ref, screeningId) {
  return ref.watch(databaseProvider).watchReferralHistory(screeningId);
});

// ---------------------------------------------------------------------------
// Writes — through the repository.
// ---------------------------------------------------------------------------

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository(ref.watch(databaseProvider));
});

/// All mutations go through here. Screens call these methods; they never build
/// a Companion or touch the database themselves.
class PatientRepository {
  PatientRepository(this._db);

  final AppDatabase _db;

  /// Add a patient. Returns the new patient id.
  Future<int> addPatient({
    required String name,
    required String phone,
    int? age,
    String? sex,
    String preferredLanguage = 'en',
  }) {
    return _db.insertPatient(
      PatientsCompanion.insert(
        name: name,
        phone: phone,
        age: Value(age),
        sex: Value(sex),
        preferredLanguage: Value(preferredLanguage),
      ),
    );
  }

  /// Update an existing patient's editable fields. Takes the current row and
  /// plain values so screens never deal with Drift's `Value` wrapper.
  Future<void> editPatient({
    required Patient existing,
    required String name,
    required String phone,
    int? age,
    String? sex,
    String preferredLanguage = 'en',
  }) async {
    await _db.updatePatient(
      existing.copyWith(
        name: name,
        phone: phone,
        age: Value(age),
        sex: Value(sex),
        preferredLanguage: preferredLanguage,
      ),
    );
  }

  Future<int> deletePatient(int id) => _db.deletePatient(id);

  /// Record a screening result for a patient. Returns the new screening id.
  Future<int> addScreening({
    required int patientId,
    required ScreeningResult result,
    DateTime? screeningDate,
    ReferralStatus referralStatus = ReferralStatus.none,
    String? referralSite,
    DateTime? nextReminderAt,
    String? notes,
  }) {
    return _db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: patientId,
        screeningDate: screeningDate ?? DateTime.now(),
        result: result,
        referralStatus: Value(referralStatus),
        referralSite: Value(referralSite),
        nextReminderAt: Value(nextReminderAt),
        notes: Value(notes),
      ),
    );
  }

  /// Advance a referral one legal step, logging the change.
  ///
  /// Throws [InvalidReferralTransition] on an illegal move — catch it and show
  /// `from.nextStates`, do not swallow it.
  Future<void> advanceReferral({
    required int screeningId,
    required ReferralStatus to,
    String? note,
  }) {
    return _db.advanceReferral(screeningId: screeningId, to: to, note: note);
  }
}

// ---------------------------------------------------------------------------
// Services (A15 / A16 / A18).
// ---------------------------------------------------------------------------

/// Local notifications. Initialised once in `main` before the first frame.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Turns screenings' `nextReminderAt` into scheduled follow-up reminders.
final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    ref.watch(databaseProvider),
    ref.watch(notificationServiceProvider),
  );
});

/// Launches maps / dialer for referral sites and patient phones.
final launcherServiceProvider =
    Provider<LauncherService>((ref) => const LauncherService());
