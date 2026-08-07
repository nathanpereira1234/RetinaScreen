import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> addPatient(String name) =>
      db.insertPatient(PatientsCompanion.insert(name: name, phone: '1'));

  Future<int> addScreening(
    int patientId, {
    required ReferralStatus status,
    required DateTime date,
  }) =>
      db.insertScreening(
        ScreeningsCompanion.insert(
          patientId: patientId,
          screeningDate: date,
          result: ScreeningResult.referable,
          referralStatus: Value(status),
        ),
      );

  group('watchDueFollowUps (A19)', () {
    test('includes referred + booked joined with patient, excludes attended',
        () async {
      final asha = await addPatient('Asha');
      final ravi = await addPatient('Ravi');
      final meena = await addPatient('Meena');
      await addScreening(asha,
          status: ReferralStatus.referred, date: DateTime(2024, 1, 1));
      await addScreening(ravi,
          status: ReferralStatus.booked, date: DateTime(2024, 1, 2));
      await addScreening(meena,
          status: ReferralStatus.attended, date: DateTime(2024, 1, 3));

      final due = await db.watchDueFollowUps().first;
      expect(due, hasLength(2));
      expect(due.map((e) => e.patient.name).toSet(), {'Asha', 'Ravi'});
      expect(
        due.every((e) => !e.screening.referralStatus.hasReachedClinic),
        isTrue,
      );
    });
  });

  group('watchRecentScreenings (A19)', () {
    test('newest first and respects the limit', () async {
      final p = await addPatient('P');
      await addScreening(p,
          status: ReferralStatus.none, date: DateTime(2024, 1, 1));
      await addScreening(p,
          status: ReferralStatus.none, date: DateTime(2024, 3, 1));
      await addScreening(p,
          status: ReferralStatus.none, date: DateTime(2024, 2, 1));

      final recent = await db.watchRecentScreenings(limit: 2).first;
      expect(recent, hasLength(2));
      expect(recent.first.screening.screeningDate, DateTime(2024, 3, 1));
      expect(recent.last.screening.screeningDate, DateTime(2024, 2, 1));
      expect(recent.first.patient.name, 'P');
    });
  });
}
