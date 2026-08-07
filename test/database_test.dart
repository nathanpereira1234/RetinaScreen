import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Patients CRUD (A09)', () {
    test('insert then read back', () async {
      final id = await db.insertPatient(
        PatientsCompanion.insert(name: 'Asha K', phone: '9876543210'),
      );
      final rows = await db.watchPatients().first;
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(rows.single.name, 'Asha K');
      expect(rows.single.preferredLanguage, 'en'); // default applied
    });

    test('watchPatient returns one, null when absent', () async {
      final id = await db.insertPatient(
        PatientsCompanion.insert(name: 'Ravi', phone: '9000000000'),
      );
      expect((await db.watchPatient(id).first)?.name, 'Ravi');
      expect(await db.watchPatient(99999).first, isNull);
    });

    test('newest first ordering', () async {
      await db.insertPatient(
        PatientsCompanion.insert(
          name: 'First',
          phone: '1',
          createdAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await db.insertPatient(
        PatientsCompanion.insert(
          name: 'Second',
          phone: '2',
          createdAt: Value(DateTime(2024, 6, 1)),
        ),
      );
      final rows = await db.watchPatients().first;
      expect(rows.map((p) => p.name), ['Second', 'First']);
    });

    test('delete removes the patient', () async {
      final id = await db.insertPatient(
        PatientsCompanion.insert(name: 'Temp', phone: '5'),
      );
      await db.deletePatient(id);
      expect(await db.watchPatients().first, isEmpty);
    });
  });

  group('Screenings + FK (A09)', () {
    Future<int> seedPatient() => db.insertPatient(
          PatientsCompanion.insert(name: 'P', phone: '1'),
        );

    test('screening links to patient and seeds an initial event', () async {
      final pid = await seedPatient();
      final sid = await db.insertScreening(
        ScreeningsCompanion.insert(
          patientId: pid,
          screeningDate: DateTime(2024, 5, 1),
          result: ScreeningResult.referable,
          referralStatus: const Value(ReferralStatus.referred),
        ),
      );

      final screenings = await db.watchScreenings(pid).first;
      expect(screenings.single.id, sid);
      expect(screenings.single.result, ScreeningResult.referable);

      // insertScreening seeds the audit trail with the initial state.
      final history = await db.watchReferralHistory(sid).first;
      expect(history, hasLength(1));
      expect(history.single.fromStatus, isNull);
      expect(history.single.toStatus, ReferralStatus.referred);
    });

    test('deleting a patient cascades to screenings', () async {
      final pid = await seedPatient();
      await db.insertScreening(
        ScreeningsCompanion.insert(
          patientId: pid,
          screeningDate: DateTime(2024, 5, 1),
          result: ScreeningResult.notReferable,
        ),
      );
      await db.deletePatient(pid);
      expect(await db.watchScreenings(pid).first, isEmpty);
    });
  });

  group('Pending referrals (A09)', () {
    test('counts referred + booked, excludes attended', () async {
      final pid = await db.insertPatient(
        PatientsCompanion.insert(name: 'P', phone: '1'),
      );
      Future<void> screening(ReferralStatus status) => db.insertScreening(
            ScreeningsCompanion.insert(
              patientId: pid,
              screeningDate: DateTime(2024, 5, 1),
              result: ScreeningResult.referable,
              referralStatus: Value(status),
            ),
          );

      await screening(ReferralStatus.referred);
      await screening(ReferralStatus.booked);
      await screening(ReferralStatus.attended);

      expect(await db.watchPendingReferrals().first, hasLength(2));
      expect(await db.watchPendingReferralCount().first, 2);
    });
  });

  group('advanceReferral transaction (A17)', () {
    Future<int> seedScreening(ReferralStatus start) async {
      final pid = await db.insertPatient(
        PatientsCompanion.insert(name: 'P', phone: '1'),
      );
      return db.insertScreening(
        ScreeningsCompanion.insert(
          patientId: pid,
          screeningDate: DateTime(2024, 5, 1),
          result: ScreeningResult.referable,
          referralStatus: Value(start),
        ),
      );
    }

    test('legal move updates status and appends an event', () async {
      final sid = await seedScreening(ReferralStatus.referred);
      await db.advanceReferral(
        screeningId: sid,
        to: ReferralStatus.attended,
        note: 'walked in',
      );

      final screening =
          (await db.watchScreenings((await db.watchPatients().first).single.id)
                  .first)
              .single;
      expect(screening.referralStatus, ReferralStatus.attended);

      final history = await db.watchReferralHistory(sid).first;
      // initial(referred) + the advance = 2 events
      expect(history, hasLength(2));
      expect(history.last.fromStatus, ReferralStatus.referred);
      expect(history.last.toStatus, ReferralStatus.attended);
      expect(history.last.note, 'walked in');
    });

    test('illegal move throws and changes nothing', () async {
      final sid = await seedScreening(ReferralStatus.referred);
      await expectLater(
        db.advanceReferral(screeningId: sid, to: ReferralStatus.treated),
        throwsA(isA<InvalidReferralTransition>()),
      );

      // Status unchanged, no new event beyond the seeded one.
      final history = await db.watchReferralHistory(sid).first;
      expect(history, hasLength(1));
    });

    test('missing screening throws StateError', () async {
      await expectLater(
        db.advanceReferral(screeningId: 424242, to: ReferralStatus.referred),
        throwsA(isA<StateError>()),
      );
    });
  });
}
