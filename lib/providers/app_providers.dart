/// THE CONTRACT (A11).
///
/// Person A owns this file; Person B's screens import *only* this. Screens
/// never import `data/database.dart` directly — if a screen needs data this
/// file does not expose, that is a request to Person A at the daily sync.
///
/// Data flows one way: Drift -> provider -> widget. Reads are streams, so the
/// UI refreshes itself after any write.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/strings.dart';
import '../models/enums.dart';
import '../models/program_metrics.dart';
import '../services/crash_reporter.dart';
import '../services/export_service.dart';
import '../services/launcher_service.dart';
import '../services/notification_service.dart';
import '../services/prefs_service.dart';
import '../services/reminder_service.dart';
import '../services/report_service.dart';
import '../rag/rag_service.dart';
import '../services/assistant.dart';
import '../services/gemma_assistant.dart';
import '../services/retinopathy_grader.dart';
import '../services/security_service.dart';
import '../services/tts_service.dart';

// Re-export the row types and domain enums so screens get them from this one
// import and never reach into `data/`.
export '../data/database.dart'
    show Patient, Screening, ReferralEvent, PatientScreening, ActivityEntry;
export '../l10n/strings.dart' show AppLanguage, AppStrings;
export '../l10n/labels.dart'
    show resultLabel, referralStatusLabel, spokenResult;
export '../services/fundus_quality.dart'
    show FundusQuality, FundusVerdict, FundusIssue;
export '../services/referral_pass.dart' show buildReferralPayload;
export '../services/tts_service.dart' show TtsService;
export '../models/enums.dart';
export '../models/program_metrics.dart' show ProgramMetrics, SiteStat;
export '../services/crash_reporter.dart' show CrashReporter;
export '../services/prefs_service.dart' show PrefsService;
export '../services/security_service.dart' show SecurityService;
export '../services/export_service.dart' show ExportService;
export '../services/launcher_service.dart' show LauncherService;
export '../services/notification_service.dart' show NotificationService;
export '../services/reminder_service.dart' show ReminderService;
export '../services/report_service.dart' show ReportService, ReportProgram;
export '../services/retinopathy_grader.dart'
    show RetinopathyGrader, RetinopathyPrediction, DrGrade;
export '../services/attendance_ai.dart' show AttendanceAi, OutreachBand;
export '../services/anomaly_detector.dart'
    show AnomalyDetector, SiteAnomaly, AnomalyKind;
export '../services/fundus_ai.dart' show FundusAi;
export '../services/assistant.dart'
    show AssistantService, AssistantEngine, TemplateAssistant;

/// Set up in `main` before the first frame, so synchronous reads work.
final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw StateError('prefsServiceProvider must be overridden in main()');
});

/// On-device security for the app lock: PIN and biometric.
final securityServiceProvider =
    Provider<SecurityService>((ref) => SecurityService());

/// The single database instance for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The chosen UI language, persisted via [PrefsService]. Changing it rebuilds
/// every screen that reads [stringsProvider].
final localeProvider =
    StateNotifierProvider<LocaleController, AppLanguage>((ref) {
  return LocaleController(ref.watch(prefsServiceProvider));
});

class LocaleController extends StateNotifier<AppLanguage> {
  LocaleController(this._prefs) : super(_prefs.language);

  final PrefsService _prefs;

  Future<void> set(AppLanguage language) async {
    state = language;
    await _prefs.setLanguage(language);
  }
}

/// Resolved strings for the current language. Screens read this.
final stringsProvider =
    Provider<AppStrings>((ref) => AppStrings.of(ref.watch(localeProvider)));

/// App-lock state. `true` = locked (show the lock screen). Starts locked when
/// the lock is enabled in preferences.
final lockControllerProvider =
    StateNotifierProvider<LockController, bool>((ref) {
  return LockController(locked: ref.watch(prefsServiceProvider).lockEnabled);
});

class LockController extends StateNotifier<bool> {
  LockController({required bool locked}) : super(locked);

  void lock() => state = true;
  void unlock() => state = false;
}

/// Light / dark / system theme, persisted via [PrefsService].
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(prefsServiceProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_prefs.themeMode);

  final PrefsService _prefs;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode);
  }
}

/// UI text scale (accessibility), persisted via [PrefsService].
final textScaleProvider =
    StateNotifierProvider<TextScaleController, double>((ref) {
  return TextScaleController(ref.watch(prefsServiceProvider));
});

class TextScaleController extends StateNotifier<double> {
  TextScaleController(this._prefs) : super(_prefs.textScale);

  final PrefsService _prefs;

  Future<void> set(double scale) async {
    state = scale;
    await _prefs.setTextScale(scale);
  }
}

/// Whether the first-run onboarding has been completed.
final onboardingSeenProvider =
    StateNotifierProvider<OnboardingController, bool>((ref) {
  return OnboardingController(ref.watch(prefsServiceProvider));
});

class OnboardingController extends StateNotifier<bool> {
  OnboardingController(this._prefs) : super(_prefs.onboardingSeen);

  final PrefsService _prefs;

  Future<void> complete() async {
    state = true;
    await _prefs.setOnboardingSeen(true);
  }
}

/// Text-to-speech for spoken result read-out.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  ref.onDispose(tts.dispose);
  return tts;
});

/// The patient assistant. Uses the on-device Gemma engine once its model has
/// been downloaded (Settings → On-device AI); until then the offline
/// [TemplateAssistant]. The whole UI is written against [AssistantService], so
/// this gate is the only switch.
final assistantServiceProvider = Provider<AssistantService>((ref) {
  final ready = ref.watch(prefsServiceProvider).gemmaInstalled;
  return ready ? const GemmaAssistant() : const TemplateAssistant();
});

/// On-device RAG store (ObjectBox vector DB over the curated knowledge base).
final ragServiceProvider = Provider<RagService>((ref) {
  final service = RagService();
  ref.onDispose(service.dispose);
  return service;
});

/// Opens + seeds the RAG store once; `true` when retrieval is available.
final ragReadyProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(ragServiceProvider);
  await service.init();
  return service.isReady;
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

/// Home dashboard (A19): pending follow-ups joined with their patient.
final dueFollowUpsProvider = StreamProvider<List<PatientScreening>>((ref) {
  return ref.watch(databaseProvider).watchDueFollowUps();
});

/// Home dashboard (A19): most recently recorded screenings.
final recentScreeningsProvider =
    StreamProvider<List<PatientScreening>>((ref) {
  return ref.watch(databaseProvider).watchRecentScreenings();
});

/// Append-only audit trail for the timeline UI.
final referralHistoryProvider =
    StreamProvider.family<List<ReferralEvent>, int>((ref, screeningId) {
  return ref.watch(databaseProvider).watchReferralHistory(screeningId);
});

/// Program-wide recent referral activity, newest first (activity-log screen).
final recentActivityProvider = StreamProvider<List<ActivityEntry>>((ref) {
  return ref.watch(databaseProvider).watchRecentActivity();
});

/// Distinct referral sites entered so far, for autocomplete.
final referralSitesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(databaseProvider).distinctReferralSites();
});

/// Every screening across all patients — the raw input to [programMetrics].
final allScreeningsProvider = StreamProvider<List<Screening>>((ref) {
  return ref.watch(databaseProvider).watchAllScreenings();
});

/// Program-level metrics (attendance lift, referral/ungradable rates), folded
/// from the registered-patient count and every screening. Recomputes live.
final programMetricsProvider = Provider<AsyncValue<ProgramMetrics>>((ref) {
  final patients = ref.watch(patientListProvider);
  final screenings = ref.watch(allScreeningsProvider);
  return patients.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (patientList) => screenings.when(
      loading: () => const AsyncValue.loading(),
      error: (err, stack) => AsyncValue.error(err, stack),
      data: (screeningList) => AsyncValue.data(
        ProgramMetrics.from(
          totalPatients: patientList.length,
          screenings: screeningList,
        ),
      ),
    ),
  );
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

  /// Every screening joined with its patient, for a CSV export. One-shot.
  Future<List<PatientScreening>> allScreeningsForExport() =>
      _db.allScreeningsForExport();

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

  /// Reschedule (or clear) a screening's follow-up reminder.
  Future<void> updateReminder(int screeningId, DateTime? when) =>
      _db.updateReminder(screeningId, when);

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
// Services (A15 / A16 / A18 / A23).
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

/// Crash / error reporting (A23). Swap the implementation for a dashboard
/// backend without touching call sites — see docs/RELEASE.md.
final crashReporterProvider =
    Provider<CrashReporter>((ref) => const LoggingCrashReporter());

/// On-device diabetic-retinopathy grader (decision support). Suggests a grade
/// for a human to confirm — see [RetinopathyGrader]; it never auto-saves.
final retinopathyGraderProvider = Provider<RetinopathyGrader>((ref) {
  final grader = RetinopathyGrader();
  ref.onDispose(grader.dispose);
  return grader;
});

/// Builds and shares per-screening PDF reports (on-device; nothing uploaded).
final reportServiceProvider =
    Provider<ReportService>((ref) => const ReportService());

/// Exports the caseload as CSV to the OS share sheet.
final exportServiceProvider =
    Provider<ExportService>((ref) => const ExportService());
