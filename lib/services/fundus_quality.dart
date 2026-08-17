import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// On-device fundus image-quality assessment — the gate that runs *before* a
/// grade is suggested or entered.
///
/// Poor-quality fundus photos are the number-one cause of ungradable
/// screenings, so catching them at capture time (and prompting a retake) is the
/// single highest-value quality feature for a real screening program. This runs
/// fully on-device on the `image` package — no network, no new native code.
///
/// It is a *capture-quality* check, not a clinical judgement: it never says
/// anything about disease, so it stays well inside the "does not diagnose"
/// line. [assess] is pure (an image in, a verdict out) and unit-tested with
/// synthetic images (`test/fundus_quality_test.dart`).
enum FundusIssue { tooDark, tooBright, blurry, lowField }

enum FundusVerdict { good, fair, poor }

class FundusQuality {
  const FundusQuality({
    required this.verdict,
    required this.score,
    required this.brightness,
    required this.sharpness,
    required this.fieldCoverage,
    required this.issues,
  });

  /// Overall verdict for the UI (green / amber / red).
  final FundusVerdict verdict;

  /// 0–1 overall quality score (for a meter).
  final double score;

  /// Mean luminance, 0–255.
  final double brightness;

  /// Variance-of-Laplacian focus measure (higher = sharper).
  final double sharpness;

  /// Fraction of the frame filled by the (non-black) retina, 0–1.
  final double fieldCoverage;

  final List<FundusIssue> issues;

  bool get isGradable => verdict != FundusVerdict.poor;

  // --- Thresholds (heuristic; tune against a pilot's camera/adapter) ---
  static const double _darkMean = 40;
  static const double _brightMean = 215;
  static const double _blurVar = 80; // below → blurry
  static const double _fairVar = 200; // below → soft focus
  static const double _lowField = 0.20;
  static const double _fairField = 0.35;

  /// Decode [bytes] and assess. Returns null when the bytes can't be decoded
  /// (treat as "unknown quality", not "good"). `decodeImage` can *throw* on
  /// malformed input (some format sniffers read past a too-short buffer), so
  /// the decode is guarded — corrupt image data must never crash a screening.
  static FundusQuality? assessBytes(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (decoded == null) return null;
    return assess(decoded);
  }

  /// Assess a decoded image. Downscales first so the cost is fixed regardless
  /// of camera resolution.
  static FundusQuality assess(img.Image image) {
    final small = img.copyResize(image, width: 256, height: 256);
    final w = small.width, h = small.height;

    // Grayscale buffer (luma).
    final gray = Float32List(w * h);
    var sum = 0.0;
    var nonBlack = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = small.getPixel(x, y);
        final l = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        gray[y * w + x] = l;
        sum += l;
        if (l > 30) nonBlack++;
      }
    }
    final mean = sum / (w * h);
    final fieldCoverage = nonBlack / (w * h);

    // Variance of the Laplacian (a standard focus measure).
    var lapSum = 0.0, lapSqSum = 0.0;
    var n = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final lap = 4 * gray[i] -
            gray[i - 1] -
            gray[i + 1] -
            gray[i - w] -
            gray[i + w];
        lapSum += lap;
        lapSqSum += lap * lap;
        n++;
      }
    }
    final lapMean = lapSum / n;
    final sharpness = (lapSqSum / n) - (lapMean * lapMean);

    // Issues + verdict.
    final issues = <FundusIssue>[];
    if (mean < _darkMean) issues.add(FundusIssue.tooDark);
    if (mean > _brightMean) issues.add(FundusIssue.tooBright);
    if (sharpness < _blurVar) issues.add(FundusIssue.blurry);
    if (fieldCoverage < _lowField) issues.add(FundusIssue.lowField);

    final hardFail = mean < _darkMean ||
        mean > _brightMean ||
        sharpness < _blurVar ||
        fieldCoverage < _lowField;
    final soft = sharpness < _fairVar || fieldCoverage < _fairField;
    final verdict = hardFail
        ? FundusVerdict.poor
        : (soft ? FundusVerdict.fair : FundusVerdict.good);

    return FundusQuality(
      verdict: verdict,
      score: _score(mean, sharpness, fieldCoverage),
      brightness: mean,
      sharpness: sharpness,
      fieldCoverage: fieldCoverage,
      issues: issues,
    );
  }

  static double _score(double mean, double sharp, double field) {
    // Each sub-score 0–1, then averaged. Deliberately simple and legible.
    final bright = mean < _darkMean || mean > _brightMean
        ? 0.2
        : (1 - ((mean - 127).abs() / 127)).clamp(0.4, 1.0);
    final focus = (sharp / (_fairVar * 2)).clamp(0.0, 1.0);
    final coverage = (field / _fairField).clamp(0.0, 1.0);
    return ((bright + focus + coverage) / 3).clamp(0.0, 1.0);
  }
}
