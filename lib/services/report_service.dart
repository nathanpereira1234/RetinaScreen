import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/database.dart';
import '../models/enums.dart';
import '../models/program_metrics.dart';
import 'referral_pass.dart';

/// Builds and shares a per-screening report as a PDF.
///
/// The document is built ENTIRELY ON-DEVICE from data already on the phone —
/// no network call, nothing uploaded. [share] and [printOut] hand the finished
/// bytes to the OS share sheet / printer, so PII leaves the device only if the
/// health worker chooses a destination. That matches the offline-first, no-PII-
/// off-device design.
///
/// The report explains a result a *human* recorded; it never states a
/// diagnosis of its own. The footer says so on every page — that line is what
/// keeps Phase 1 outside SaMD (B08). Do not add a computed clinical judgement
/// here.
///
/// [buildScreeningReport] is pure (bytes in, bytes out) so it is unit-testable
/// without a platform channel (`test/report_service_test.dart`); only [share]
/// and [printOut] touch the platform.
class ReportService {
  const ReportService({this.program = ReportProgram.defaultProgram});

  final ReportProgram program;

  /// A neutral filename — the patient's name lives inside the document, not in
  /// the shared file's title.
  String _fileName(Screening s) =>
      'screening-report-${s.patientId}-'
      '${DateFormat('yyyyMMdd').format(s.screeningDate)}.pdf';

  Future<void> share({
    required Patient patient,
    required Screening screening,
    required List<ReferralEvent> history,
  }) async {
    final bytes = await buildScreeningReport(
      program: program,
      patient: patient,
      screening: screening,
      history: history,
    );
    await Printing.sharePdf(bytes: bytes, filename: _fileName(screening));
  }

  Future<void> printOut({
    required Patient patient,
    required Screening screening,
    required List<ReferralEvent> history,
  }) async {
    await Printing.layoutPdf(
      name: _fileName(screening),
      onLayout: (_) => buildScreeningReport(
        program: program,
        patient: patient,
        screening: screening,
        history: history,
      ),
    );
  }

  /// Share a program-summary PDF (the metrics dashboard as a document funders
  /// and partners can be handed). Built on-device.
  Future<void> shareProgramSummary({
    required ProgramMetrics metrics,
    required List<SiteStat> sites,
    required String rangeLabel,
  }) async {
    final bytes = await buildProgramSummary(
      program: program,
      metrics: metrics,
      sites: sites,
      rangeLabel: rangeLabel,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'program-summary.pdf');
  }

  /// Render the program-summary PDF. Pure.
  static Future<Uint8List> buildProgramSummary({
    required ReportProgram program,
    required ProgramMetrics metrics,
    required List<SiteStat> sites,
    required String rangeLabel,
  }) async {
    final doc = pw.Document();
    String pct(double v) => '${(v * 100).round()}%';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => _footer(context, program),
        build: (context) => [
          _header(program),
          pw.SizedBox(height: 16),
          pw.Text('Program summary',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: $rangeLabel',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          _resultBanner(
            'Attendance rate: ${pct(metrics.attendanceRate)}  '
            '(${metrics.reachedClinicCount} of ${metrics.referredCount} referred '
            'reached the clinic — booking alone does not count)',
            PdfColors.teal700,
          ),
          pw.SizedBox(height: 16),
          _sectionTitle('Totals'),
          _kvTable({
            'Patients': '${metrics.totalPatients}',
            'Screenings': '${metrics.totalScreenings}',
            'Referable': '${metrics.referableCount}',
            'Ungradable': '${metrics.ungradableCount}',
            'Pending follow-up': '${metrics.pendingCount}',
            'Reached clinic': '${metrics.reachedClinicCount}',
            'Treated': '${metrics.treatedCount}',
            'Referral rate': pct(metrics.referralRate),
            'Ungradable rate': pct(metrics.ungradableRate),
          }),
          if (sites.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('By referral site'),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _siteRow('Site', 'Screened', 'Referred', 'Reached', header: true),
                for (final st in sites)
                  _siteRow('${st.site}', '${st.screened}', '${st.referred}',
                      '${st.reached} (${pct(st.attendanceRate)})'),
              ],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static pw.TableRow _siteRow(
    String a,
    String b,
    String c,
    String d, {
    bool header = false,
  }) {
    pw.Widget cell(String t) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            t,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );
    return pw.TableRow(children: [cell(a), cell(b), cell(c), cell(d)]);
  }

  /// Render the report to PDF bytes. Pure — no I/O, no platform channel.
  static Future<Uint8List> buildScreeningReport({
    required ReportProgram program,
    required Patient patient,
    required Screening screening,
    required List<ReferralEvent> history,
  }) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');
    final dateTimeFmt = DateFormat('dd MMM yyyy, HH:mm');
    final (resultLabel, resultColor) = _resultStyle(screening.result);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => _footer(context, program),
        build: (context) => [
          _header(program),
          pw.SizedBox(height: 16),
          pw.Text(
            'Screening report',
            style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${dateTimeFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),
          _sectionTitle('Patient'),
          _kvTable({
            'Name': patient.name,
            if (patient.age != null) 'Age': '${patient.age}',
            if (patient.sex != null && patient.sex!.isNotEmpty)
              'Sex': patient.sex!,
            if (patient.phone.isNotEmpty) 'Phone': patient.phone,
          }),
          pw.SizedBox(height: 16),
          _sectionTitle('Screening'),
          _resultBanner(resultLabel, resultColor),
          pw.SizedBox(height: 8),
          _kvTable({
            'Date': dateFmt.format(screening.screeningDate),
            'Referral status': _statusLabel(screening.referralStatus),
            if (screening.referralSite != null &&
                screening.referralSite!.isNotEmpty)
              'Referral site': screening.referralSite!,
            if (screening.nextReminderAt != null)
              'Follow-up reminder': dateFmt.format(screening.nextReminderAt!),
            if (screening.notes != null && screening.notes!.isNotEmpty)
              'Notes': screening.notes!,
          }),
          pw.SizedBox(height: 16),
          _sectionTitle('What this means'),
          pw.Text(
            _resultExplanation(screening.result),
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _nextSteps(screening.result, screening.referralStatus),
            style: const pw.TextStyle(fontSize: 11),
          ),
          if (history.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Referral history'),
            _timeline(history, dateTimeFmt),
          ],
          pw.SizedBox(height: 16),
          _sectionTitle('Referral pass'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: buildReferralPayload(
                  patient: patient,
                  screening: screening,
                ),
                width: 96,
                height: 96,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Text(
                  'Scan at the referral clinic to intake this patient without '
                  're-typing.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // --- PDF building blocks ---

  static pw.Widget _header(ReportProgram program) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            program.name,
            style:
                const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          if (program.subtitle.isNotEmpty)
            pw.Text(
              program.subtitle,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          pw.Divider(color: PdfColors.grey400),
        ],
      );

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: const pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      );

  static pw.Widget _kvTable(Map<String, String> rows) => pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(120),
          1: const pw.FlexColumnWidth(),
        },
        children: [
          for (final entry in rows.entries)
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(
                    entry.key,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(
                    entry.value,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
        ],
      );

  static pw.Widget _resultBanner(String label, PdfColor color) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          label,
          style: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  static pw.Widget _timeline(
    List<ReferralEvent> history,
    DateFormat fmt,
  ) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final e in history)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '• ${fmt.format(e.occurredAt)} — '
                '${e.fromStatus == null ? 'recorded' : '${_statusLabel(e.fromStatus!)} -> ${_statusLabel(e.toStatus)}'}'
                '${e.note != null && e.note!.isNotEmpty ? ' (${e.note})' : ''}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
        ],
      );

  static pw.Widget _footer(pw.Context context, ReportProgram program) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            program.disclaimer,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      );

  // --- Plain-language copy ---

  static (String, PdfColor) _resultStyle(ScreeningResult r) => switch (r) {
        ScreeningResult.referable => (
            'Referable — see an eye doctor',
            PdfColors.red700,
          ),
        ScreeningResult.notReferable => (
            'Not referable — no urgent concern found',
            PdfColors.green700,
          ),
        ScreeningResult.ungradable => (
            'Ungradable — needs to be screened again',
            PdfColors.orange700,
          ),
      };

  static String _statusLabel(ReferralStatus s) => switch (s) {
        ReferralStatus.none => 'No referral',
        ReferralStatus.referred => 'Referred',
        ReferralStatus.booked => 'Appointment booked',
        ReferralStatus.attended => 'Attended clinic',
        ReferralStatus.treated => 'Treated',
      };

  static String _resultExplanation(ScreeningResult r) => switch (r) {
        ScreeningResult.referable =>
          'The screening found signs that should be checked by an eye doctor '
              '(ophthalmologist). This is not a diagnosis — the eye doctor will '
              'examine the eyes and decide what, if anything, is needed. Most '
              'eye problems found early can be treated.',
        ScreeningResult.notReferable =>
          'No signs needing an eye-doctor visit were found on this screening. '
              'This is not a guarantee — diabetes can affect the eyes over time, '
              'so continue regular screening as advised.',
        ScreeningResult.ungradable =>
          'The images were not clear enough to read confidently. This does not '
              'mean anything is wrong — it means the screening should be done '
              'again so a clear result can be recorded.',
      };

  static String _nextSteps(ScreeningResult r, ReferralStatus status) {
    if (r == ScreeningResult.referable && !status.hasReachedClinic) {
      return 'Next step: visit the referral site above. Bring this report. '
          'Attending the appointment is the most important thing you can do.';
    }
    if (r == ScreeningResult.ungradable) {
      return 'Next step: arrange to be screened again.';
    }
    if (status.hasReachedClinic) {
      return 'Next step: follow the eye doctor\'s advice and keep managing '
          'your diabetes.';
    }
    return 'Next step: keep up regular screening as advised by your health '
        'worker.';
  }
}

/// Program identity printed on the report. Swap for the pilot partner's name /
/// contact without touching the layout code.
class ReportProgram {
  const ReportProgram({
    required this.name,
    this.subtitle = '',
    required this.disclaimer,
  });

  final String name;
  final String subtitle;
  final String disclaimer;

  static const defaultProgram = ReportProgram(
    name: 'RetinaScreen',
    subtitle: 'Diabetic retinopathy screening program',
    disclaimer:
        'This report explains a screening result recorded by a trained health '
        'worker. It is not a medical diagnosis and does not replace an '
        'examination by an eye doctor. Generated on-device; no data was sent '
        'over the internet to produce it.',
  );
}
