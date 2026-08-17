import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';

/// Exports the program's caseload as a flat CSV and hands it to the OS share
/// sheet.
///
/// The whole point of the export is that field devices hold the only copy of
/// the data (README: "Field devices hold the only copy of patient data") — a
/// lost phone loses the program's evidence. This is the escape hatch: a
/// program manager can pull a CSV backup / analysis file off the device.
///
/// The file is a deliberate, user-initiated share. [toCsv] is a pure function
/// (rows in, string out) with RFC-4180 escaping, unit-tested without any I/O
/// (`test/export_service_test.dart`); only [shareCsv] touches the filesystem
/// and the share sheet.
class ExportService {
  const ExportService();

  static const List<String> _columns = [
    'patient_id',
    'name',
    'age',
    'sex',
    'phone',
    'preferred_language',
    'screening_id',
    'screening_date',
    'result',
    'referral_status',
    'referral_site',
    'next_reminder_at',
    'notes',
    'created_at',
  ];

  /// Build a CSV document from joined patient+screening rows. Pure.
  static String toCsv(List<PatientScreening> rows) {
    final date = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer()..writeln(_columns.map(_escape).join(','));
    for (final row in rows) {
      final p = row.patient;
      final s = row.screening;
      buffer.writeln([
        p.id,
        p.name,
        p.age?.toString() ?? '',
        p.sex ?? '',
        p.phone,
        p.preferredLanguage,
        s.id,
        date.format(s.screeningDate),
        s.result.name,
        s.referralStatus.name,
        s.referralSite ?? '',
        s.nextReminderAt == null ? '' : date.format(s.nextReminderAt!),
        s.notes ?? '',
        date.format(s.createdAt),
      ].map((v) => _escape('$v')).join(','));
    }
    return buffer.toString();
  }

  /// Write the CSV to a temp file and open the share sheet. Returns false when
  /// there is nothing to export.
  Future<bool> shareCsv(List<PatientScreening> rows) async {
    if (rows.isEmpty) return false;
    final csv = toCsv(rows);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final file = File('${dir.path}/retinascreen-export-$stamp.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'RetinaScreen export',
    );
    return true;
  }

  /// RFC-4180 field escaping: quote when the value contains a comma, quote, or
  /// newline, and double any embedded quotes.
  static String _escape(String value) {
    if (value.contains(RegExp(r'[",\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
