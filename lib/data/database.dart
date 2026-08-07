import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/enums.dart';

// Re-export Drift's Value wrapper so files working with this database's
// Companions (providers, tests) get it from here, not a bare drift import.
export 'package:drift/drift.dart' show Value;

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables (A07, A08)
//
// Enums are stored as TEXT (their `.name`), not as an index. Text survives
// reordering the enum; an int index silently corrupts data if a value is ever
// inserted in the middle. Given "migrations only add," text is the safe choice.
// ---------------------------------------------------------------------------

/// One person screened by the program (A07).
class Patients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get age => integer().nullable()();
  TextColumn get sex => text().nullable()();
  TextColumn get phone => text().withLength(min: 0, max: 20)();
  TextColumn get preferredLanguage =>
      text().withDefault(const Constant('en'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// One screening event for a patient, plus its current referral state (A08).
class Screenings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get patientId =>
      integer().references(Patients, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get screeningDate => dateTime()();
  TextColumn get result => textEnum<ScreeningResult>()();
  TextColumn get referralStatus => textEnum<ReferralStatus>()
      .withDefault(Constant(ReferralStatus.none.name))();
  TextColumn get referralSite => text().nullable()();
  DateTimeColumn get nextReminderAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Append-only audit trail of every referral state change.
///
/// LOAD-BEARING: this is the evidence for the Phase 1 success claim (attendance
/// lift vs. baseline, B06/B26). Rows are never updated or deleted — a
/// correction is a new event with a note.
class ReferralEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get screeningId =>
      integer().references(Screenings, #id, onDelete: KeyAction.cascade)();

  /// Null only for the very first event (initial state had no predecessor).
  TextColumn get fromStatus => textEnum<ReferralStatus>().nullable()();
  TextColumn get toStatus => textEnum<ReferralStatus>()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A screening joined with its patient — the shape the home dashboard needs
/// (A19). Read-only view model; not a table.
class PatientScreening {
  PatientScreening({required this.patient, required this.screening});

  final Patient patient;
  final Screening screening;
}

// ---------------------------------------------------------------------------
// Database (A06, A10) + queries / DAO (A09) + referral transaction (A17)
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Patients, Screenings, ReferralEvents])
class AppDatabase extends _$AppDatabase {
  /// Production constructor opens the on-device file. Tests pass an in-memory
  /// executor: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'retinascreen'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // MIGRATIONS ONLY ADD. Field devices hold the only copy of patient
          // data. Add tables/columns here per `from`; never drop a column that
          // holds real data without a tested migration path.
        },
        beforeOpen: (details) async {
          // Best-effort referential integrity (e.g. rejecting a screening that
          // points at a missing patient). Deletion does NOT depend on this —
          // see deletePatient — because the pragma is per-connection and not
          // reliably applied everywhere (notably the in-memory test executor).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // --- Patients (A09) ---

  /// All patients, newest first. Reactive: emits again after any write.
  Stream<List<Patient>> watchPatients() {
    return (select(patients)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Stream<Patient?> watchPatient(int id) {
    return (select(patients)..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<int> insertPatient(PatientsCompanion patient) =>
      into(patients).insert(patient);

  Future<bool> updatePatient(Patient patient) =>
      update(patients).replace(patient);

  /// Delete a patient together with all of their screenings and referral
  /// events. Returns the number of patient rows removed.
  ///
  /// Done explicitly in a transaction rather than trusting SQLite's FK cascade:
  /// `PRAGMA foreign_keys` enforcement is per-connection and easy to have off
  /// (it isn't reliably applied in the in-memory test setup), so children are
  /// removed deterministically. This is also the consent-revocation / DPDP
  /// "delete my data" path, where leaving orphaned rows behind is unacceptable.
  Future<int> deletePatient(int id) {
    return transaction(() async {
      final screeningIds = await (select(screenings)
            ..where((s) => s.patientId.equals(id)))
          .map((s) => s.id)
          .get();
      if (screeningIds.isNotEmpty) {
        await (delete(referralEvents)
              ..where((e) => e.screeningId.isIn(screeningIds)))
            .go();
        await (delete(screenings)..where((s) => s.patientId.equals(id))).go();
      }
      return (delete(patients)..where((p) => p.id.equals(id))).go();
    });
  }

  // --- Screenings (A09) ---

  /// A patient's screening history, newest first.
  Stream<List<Screening>> watchScreenings(int patientId) {
    return (select(screenings)
          ..where((s) => s.patientId.equals(patientId))
          ..orderBy([(s) => OrderingTerm.desc(s.screeningDate)]))
        .watch();
  }

  Future<int> insertScreening(ScreeningsCompanion screening) {
    return transaction(() async {
      final id = await into(screenings).insert(screening);
      final status =
          screening.referralStatus.present
              ? screening.referralStatus.value
              : ReferralStatus.none;
      // Seed the audit trail with the initial state (fromStatus == null).
      await into(referralEvents).insert(
        ReferralEventsCompanion.insert(
          screeningId: id,
          fromStatus: const Value.absent(),
          toStatus: status,
          note: const Value('screening recorded'),
        ),
      );
      return id;
    });
  }

  /// Screenings referred but not yet attended (referred OR booked). These are
  /// the follow-ups a health worker still needs to chase.
  Stream<List<Screening>> watchPendingReferrals() {
    return (select(screenings)
          ..where(
            (s) => s.referralStatus.isInValues([
              ReferralStatus.referred,
              ReferralStatus.booked,
            ]),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.nextReminderAt)]))
        .watch();
  }

  /// Count of pending referrals, for the home-screen badge.
  Stream<int> watchPendingReferralCount() {
    final count = screenings.id.count();
    final query = selectOnly(screenings)
      ..addColumns([count])
      ..where(
        screenings.referralStatus.isInValues([
          ReferralStatus.referred,
          ReferralStatus.booked,
        ]),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  // --- Home dashboard (A19) ---

  /// Screenings still pending follow-up (referred or booked), each joined with
  /// its patient, soonest reminder first. Feeds the health-worker home.
  Stream<List<PatientScreening>> watchDueFollowUps() {
    final query = select(screenings).join([
      innerJoin(patients, patients.id.equalsExp(screenings.patientId)),
    ]);
    query
      ..where(
        screenings.referralStatus.isInValues([
          ReferralStatus.referred,
          ReferralStatus.booked,
        ]),
      )
      ..orderBy([OrderingTerm.asc(screenings.nextReminderAt)]);
    return query
        .map(
          (row) => PatientScreening(
            patient: row.readTable(patients),
            screening: row.readTable(screenings),
          ),
        )
        .watch();
  }

  /// The most recently recorded screenings across all patients.
  Stream<List<PatientScreening>> watchRecentScreenings({int limit = 10}) {
    final query = select(screenings).join([
      innerJoin(patients, patients.id.equalsExp(screenings.patientId)),
    ]);
    query
      ..orderBy([OrderingTerm.desc(screenings.screeningDate)])
      ..limit(limit);
    return query
        .map(
          (row) => PatientScreening(
            patient: row.readTable(patients),
            screening: row.readTable(screenings),
          ),
        )
        .watch();
  }

  // --- Referral events (A17) ---

  /// The audit trail for one screening, oldest first (for a timeline UI).
  Stream<List<ReferralEvent>> watchReferralHistory(int screeningId) {
    return (select(referralEvents)
          ..where((e) => e.screeningId.equals(screeningId))
          ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
        .watch();
  }

  /// Move a screening's referral to [to], enforcing the state machine and
  /// recording the change as an append-only [ReferralEvents] row — atomically.
  ///
  /// Throws [StateError] if the screening does not exist, or
  /// [InvalidReferralTransition] if the move is illegal.
  Future<void> advanceReferral({
    required int screeningId,
    required ReferralStatus to,
    String? note,
  }) {
    return transaction(() async {
      final screening = await (select(screenings)
            ..where((s) => s.id.equals(screeningId)))
          .getSingleOrNull();
      if (screening == null) {
        throw StateError('Screening $screeningId not found');
      }

      final from = screening.referralStatus;
      if (!from.canTransitionTo(to)) {
        throw InvalidReferralTransition(from, to);
      }

      await (update(screenings)..where((s) => s.id.equals(screeningId)))
          .write(ScreeningsCompanion(referralStatus: Value(to)));

      await into(referralEvents).insert(
        ReferralEventsCompanion.insert(
          screeningId: screeningId,
          fromStatus: Value(from),
          toStatus: to,
          note: Value(note),
        ),
      );
    });
  }
}
