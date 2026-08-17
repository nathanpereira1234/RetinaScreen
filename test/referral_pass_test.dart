import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';
import 'package:retinascreen/services/referral_pass.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('payload is valid JSON with the referral fields', () async {
    final pid = await db.insertPatient(
      PatientsCompanion.insert(
        name: 'Asha K',
        phone: '9876543210',
        age: const Value(54),
      ),
    );
    final sid = await db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: pid,
        screeningDate: DateTime(2024, 5, 1),
        result: ScreeningResult.referable,
        referralStatus: const Value(ReferralStatus.referred),
        referralSite: const Value('District Vision Centre'),
      ),
    );
    final patient = (await db.watchPatient(pid).first)!;
    final screening = (await db.watchScreenings(pid).first).single;

    final json = jsonDecode(
      buildReferralPayload(patient: patient, screening: screening),
    ) as Map<String, dynamic>;

    expect(json['v'], 1);
    expect(json['ref'], 'P$pid-S$sid');
    expect(json['name'], 'Asha K');
    expect(json['age'], 54);
    expect(json['result'], 'referable');
    expect(json['status'], 'referred');
    expect(json['site'], 'District Vision Centre');
    expect(json['date'], '2024-05-01');
  });

  test('omits optional fields when absent', () async {
    final pid = await db.insertPatient(
      PatientsCompanion.insert(name: 'Ravi', phone: '1'),
    );
    await db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: pid,
        screeningDate: DateTime(2024, 5, 1),
        result: ScreeningResult.notReferable,
      ),
    );
    final patient = (await db.watchPatient(pid).first)!;
    final screening = (await db.watchScreenings(pid).first).single;

    final json = jsonDecode(
      buildReferralPayload(patient: patient, screening: screening),
    ) as Map<String, dynamic>;

    expect(json.containsKey('age'), isFalse);
    expect(json.containsKey('site'), isFalse);
    expect(json['result'], 'notReferable');
  });
}
