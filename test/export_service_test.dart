import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';
import 'package:retinascreen/services/export_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('empty export is header-only', () {
    final csv = ExportService.toCsv([]);
    final lines = csv.trim().split('\n');
    expect(lines, hasLength(1));
    expect(lines.single, startsWith('patient_id,name,age'));
  });

  test('one row round-trips through the joined query', () async {
    final pid = await db.insertPatient(
      PatientsCompanion.insert(name: 'Asha K', phone: '9876543210'),
    );
    await db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: pid,
        screeningDate: DateTime(2024, 5, 1),
        result: ScreeningResult.referable,
        referralStatus: const Value(ReferralStatus.referred),
      ),
    );

    final csv = ExportService.toCsv(await db.allScreeningsForExport());
    final lines = csv.trim().split('\n');
    expect(lines, hasLength(2)); // header + one data row
    expect(lines[1], contains('Asha K'));
    expect(lines[1], contains('9876543210'));
    expect(lines[1], contains('2024-05-01'));
    expect(lines[1], contains('referable'));
    expect(lines[1], contains('referred'));
  });

  test('fields with commas, quotes and newlines are RFC-4180 escaped',
      () async {
    final pid = await db.insertPatient(
      PatientsCompanion.insert(name: 'Doe, Jane', phone: '1'),
    );
    await db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: pid,
        screeningDate: DateTime(2024, 5, 1),
        result: ScreeningResult.notReferable,
        notes: const Value('line one\nline "two"'),
      ),
    );

    final csv = ExportService.toCsv(await db.allScreeningsForExport());
    // Name with a comma is quoted.
    expect(csv, contains('"Doe, Jane"'));
    // Embedded quotes are doubled inside a quoted field.
    expect(csv, contains('"line one\nline ""two"""'));
  });
}
