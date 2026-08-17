import 'dart:convert';

import '../data/database.dart';

/// Builds the compact payload encoded in a screening's referral QR code.
///
/// The QR is a hand-off: a health worker shows it at the referral clinic and
/// the clinic scans it to intake the patient without re-typing anything. The
/// payload is small, self-describing JSON so a future clinic-side reader can
/// parse it. It contains the same identifying fields already printed on the
/// report — the worker chooses to show it, so no data leaves the device
/// automatically.
///
/// Pure function (rows in, string out); unit-tested in
/// `test/referral_pass_test.dart`.
String buildReferralPayload({
  required Patient patient,
  required Screening screening,
}) {
  final map = <String, Object?>{
    'v': 1,
    'ref': 'P${patient.id}-S${screening.id}',
    'name': patient.name,
    if (patient.age != null) 'age': patient.age,
    'result': screening.result.name,
    'status': screening.referralStatus.name,
    if (screening.referralSite != null && screening.referralSite!.isNotEmpty)
      'site': screening.referralSite,
    'date': screening.screeningDate.toIso8601String().split('T').first,
  };
  return jsonEncode(map);
}
