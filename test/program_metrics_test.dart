import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';
import 'package:retinascreen/models/program_metrics.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> addPatient(String name) =>
      db.insertPatient(PatientsCompanion.insert(name: name, phone: '1'));

  Future<void> addScreening(
    int patientId, {
    required ScreeningResult result,
    ReferralStatus status = ReferralStatus.none,
  }) =>
      db.insertScreening(
        ScreeningsCompanion.insert(
          patientId: patientId,
          screeningDate: DateTime(2024, 1, 1),
          result: result,
          referralStatus: Value(status),
        ),
      );

  test('empty program is all zeros with safe (zero) rates', () {
    const m = ProgramMetrics.empty;
    expect(m.totalScreenings, 0);
    expect(m.attendanceRate, 0);
    expect(m.referralRate, 0);
    expect(m.ungradableRate, 0);
    expect(m.treatmentRate, 0);
  });

  test('folds counts from every screening', () async {
    final p = await addPatient('P');
    await addScreening(p, result: ScreeningResult.referable,
        status: ReferralStatus.referred);
    await addScreening(p, result: ScreeningResult.notReferable);
    await addScreening(p, result: ScreeningResult.ungradable);

    final metrics = ProgramMetrics.from(
      totalPatients: 1,
      screenings: await db.watchAllScreenings().first,
    );

    expect(metrics.totalPatients, 1);
    expect(metrics.totalScreenings, 3);
    expect(metrics.referableCount, 1);
    expect(metrics.ungradableCount, 1);
    expect(metrics.referredCount, 1);
    expect(metrics.ungradableRate, closeTo(1 / 3, 1e-9));
  });

  test('attendance rate counts attended/treated but NOT booked', () async {
    final p = await addPatient('P');
    // 4 referred; 1 still referred, 1 booked, 1 attended, 1 treated.
    await addScreening(p, result: ScreeningResult.referable,
        status: ReferralStatus.referred);
    await addScreening(p, result: ScreeningResult.referable,
        status: ReferralStatus.booked);
    await addScreening(p, result: ScreeningResult.referable,
        status: ReferralStatus.attended);
    await addScreening(p, result: ScreeningResult.referable,
        status: ReferralStatus.treated);

    final m = ProgramMetrics.from(
      totalPatients: 1,
      screenings: await db.watchAllScreenings().first,
    );

    expect(m.referredCount, 4);
    // Only attended + treated reached the clinic. Booked must NOT count.
    expect(m.reachedClinicCount, 2);
    expect(m.treatedCount, 1);
    expect(m.pendingCount, 2); // referred + booked
    expect(m.attendanceRate, closeTo(0.5, 1e-9));
    expect(m.treatmentRate, closeTo(0.5, 1e-9)); // 1 treated of 2 reached
  });

  test('a lone booked screening yields 0% attendance, not 100%', () async {
    final p = await addPatient('P');
    await addScreening(p, result: ScreeningResult.referable,
        status: ReferralStatus.booked);

    final m = ProgramMetrics.from(
      totalPatients: 1,
      screenings: await db.watchAllScreenings().first,
    );

    expect(m.referredCount, 1);
    expect(m.reachedClinicCount, 0);
    expect(m.attendanceRate, 0);
  });
}
