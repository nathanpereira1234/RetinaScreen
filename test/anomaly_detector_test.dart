import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/data/database.dart';
import 'package:retinascreen/models/enums.dart';
import 'package:retinascreen/services/anomaly_detector.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> add(String site, ScreeningResult result) async {
    final pid = await db.insertPatient(
      PatientsCompanion.insert(name: site, phone: '1'),
    );
    await db.insertScreening(
      ScreeningsCompanion.insert(
        patientId: pid,
        screeningDate: DateTime(2024, 1, 1),
        result: result,
        referralSite: Value(site),
      ),
    );
  }

  test('flags a site whose ungradable rate is an outlier', () async {
    // Sites B–E are clean; site A is all ungradable — a clear outlier.
    for (final site in ['B', 'C', 'D', 'E']) {
      for (var i = 0; i < 6; i++) {
        await add(site, ScreeningResult.notReferable);
      }
    }
    for (var i = 0; i < 6; i++) {
      await add('A', ScreeningResult.ungradable);
    }

    final anomalies =
        AnomalyDetector.detect(await db.watchAllScreenings().first);
    expect(anomalies.any((a) => a.site == 'A'), isTrue);
    expect(
      anomalies.firstWhere((a) => a.site == 'A').kind,
      AnomalyKind.highUngradable,
    );
  });

  test('no anomalies when sites are uniform', () async {
    for (final site in ['A', 'B', 'C']) {
      for (var i = 0; i < 6; i++) {
        await add(site, ScreeningResult.notReferable);
      }
    }
    expect(
      AnomalyDetector.detect(await db.watchAllScreenings().first),
      isEmpty,
    );
  });

  test('too few sites → no judgement', () async {
    for (var i = 0; i < 6; i++) {
      await add('A', ScreeningResult.ungradable);
    }
    expect(
      AnomalyDetector.detect(await db.watchAllScreenings().first),
      isEmpty,
    );
  });
}
