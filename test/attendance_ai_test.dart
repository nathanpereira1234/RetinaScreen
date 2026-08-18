import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';
import 'package:retinascreen/services/attendance_ai.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2024, 6, 1);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<Screening> mk({
    required ReferralStatus status,
    required DateTime date,
    DateTime? reminder,
    ScreeningResult result = ScreeningResult.referable,
  }) async {
    final pid = await db.insertPatient(
      PatientsCompanion.insert(name: 'P', phone: '1'),
    );
    await db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: pid,
        screeningDate: date,
        result: result,
        referralStatus: Value(status),
        nextReminderAt: Value(reminder),
      ),
    );
    return (await db.watchScreenings(pid).first).single;
  }

  test('probability is a valid 0..1 value', () async {
    final s = await mk(status: ReferralStatus.referred, date: now);
    final p = AttendanceAi.noShowProbability(s, now: now);
    expect(p, inInclusiveRange(0.0, 1.0));
  });

  test('a booked appointment lowers no-show risk vs just-referred', () async {
    final booked = await mk(status: ReferralStatus.booked, date: now);
    final referred = await mk(status: ReferralStatus.referred, date: now);
    expect(
      AttendanceAi.noShowProbability(booked, now: now),
      lessThan(AttendanceAi.noShowProbability(referred, now: now)),
    );
  });

  test('an overdue reminder raises no-show risk', () async {
    final overdue = await mk(
      status: ReferralStatus.referred,
      date: now,
      reminder: now.subtract(const Duration(days: 5)),
    );
    final future = await mk(
      status: ReferralStatus.referred,
      date: now,
      reminder: now.add(const Duration(days: 5)),
    );
    expect(
      AttendanceAi.noShowProbability(overdue, now: now),
      greaterThan(AttendanceAi.noShowProbability(future, now: now)),
    );
  });

  test('outreach priority stays within 0..1', () async {
    final s = await mk(status: ReferralStatus.referred, date: now);
    expect(AttendanceAi.outreachPriority(s, now: now), inInclusiveRange(0.0, 1.0));
  });

  test('referable cases are reminded sooner than routine ones', () {
    final from = DateTime(2024, 1, 1);
    final referable = AttendanceAi.suggestReminderDate(
        ScreeningResult.referable, ReferralStatus.referred,
        from: from);
    final routine = AttendanceAi.suggestReminderDate(
        ScreeningResult.notReferable, ReferralStatus.none,
        from: from);
    expect(referable.isBefore(routine), isTrue);
  });
}
