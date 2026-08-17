import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';
import 'package:retinascreen/services/report_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<(Patient, Screening, List<ReferralEvent>)> seed({
    ReferralStatus status = ReferralStatus.referred,
  }) async {
    final pid = await db.insertPatient(
      PatientsCompanion.insert(name: 'Asha K', phone: '9876543210', age: const Value(54)),
    );
    final sid = await db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: pid,
        screeningDate: DateTime(2024, 5, 1),
        result: ScreeningResult.referable,
        referralStatus: Value(status),
        referralSite: const Value('District Vision Centre'),
      ),
    );
    final patient = (await db.watchPatient(pid).first)!;
    final screening = (await db.watchScreenings(pid).first).single;
    final history = await db.watchReferralHistory(sid).first;
    return (patient, screening, history);
  }

  test('produces a non-empty PDF document', () async {
    final (patient, screening, history) = await seed();
    final bytes = await ReportService.buildScreeningReport(
      program: ReportProgram.defaultProgram,
      patient: patient,
      screening: screening,
      history: history,
    );

    expect(bytes, isNotEmpty);
    // A valid PDF starts with the "%PDF" magic bytes.
    expect(utf8.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('builds for every result/status combination without throwing',
      () async {
    for (final status in ReferralStatus.values) {
      final (patient, screening, history) = await seed(status: status);
      final bytes = await ReportService.buildScreeningReport(
        program: ReportProgram.defaultProgram,
        patient: patient,
        screening: screening,
        history: history,
      );
      expect(bytes, isNotEmpty, reason: 'status $status');
    }
  });
}
