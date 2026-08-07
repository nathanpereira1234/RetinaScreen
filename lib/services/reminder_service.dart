import '../data/database.dart';
import 'notification_service.dart';

/// The reminder scheduling engine (A16).
///
/// Turns a screening's `nextReminderAt` into a scheduled notification keyed by
/// the screening id, so rescheduling or cancelling is idempotent.
class ReminderService {
  ReminderService(this._db, this._notifications);

  final AppDatabase _db;
  final NotificationService _notifications;

  /// (Re)schedule the reminder for one screening. Cancels instead when there
  /// is no reminder time, or once the patient has reached the clinic — the
  /// point of the reminder has passed, so stop nagging.
  Future<void> scheduleForScreening(
    Screening screening, {
    String? patientName,
  }) {
    final when = screening.nextReminderAt;
    if (when == null || screening.referralStatus.hasReachedClinic) {
      return _notifications.cancel(screening.id);
    }
    return _notifications.schedule(
      id: screening.id,
      title: 'Follow-up due',
      body: patientName == null
          ? 'A patient has a pending eye-clinic referral.'
          : '$patientName has a pending eye-clinic referral.',
      when: when,
      patientId: screening.patientId,
    );
  }

  /// Reschedule reminders for every still-pending referral. Call at startup so
  /// reminders survive an app restart / device reboot.
  Future<void> syncAll() async {
    final pending = await _db.watchPendingReferrals().first;
    for (final screening in pending) {
      await scheduleForScreening(screening);
    }
  }
}
