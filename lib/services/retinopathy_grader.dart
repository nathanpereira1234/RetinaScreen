import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/enums.dart';

/// On-device diabetic-retinopathy grading — **decision support only**.
///
/// This produces a SUGGESTION for a human to confirm; it never writes a result
/// on its own. The stored [ScreeningResult] is always the value the health
/// worker confirms in the form. Keeping a human in the loop is what preserves
/// the Phase-1 "we explain and remind, we do not diagnose" line (B08) — do NOT
/// wire this to auto-save.
///
/// Inference runs fully on-device (TFLite): the fundus image never leaves the
/// phone, matching the offline-first / no-PII-off-device design.
class RetinopathyGrader {
  RetinopathyGrader();

  Interpreter? _interpreter;
  bool _triedLoad = false;

  /// Bundled model path. Convert a trained APTOS/EyePACS classifier to TFLite
  /// and drop it here — see `assets/models/README.md`.
  static const String _modelAsset = 'assets/models/dr_model.tflite';

  /// Square RGB input edge, in pixels. MUST match how the model was trained
  /// (224 for most EfficientNet-B0/B3 and ResNet exports; adjust otherwise).
  static const int _inputSize = 224;

  /// Per-channel normalisation applied as `(pixel - _mean) / _std`.
  ///
  /// Defaults scale raw 0–255 pixels to [0, 1], which most APTOS exports expect.
  /// If your model was trained with ImageNet mean/std, change these to match —
  /// a mismatch here silently wrecks accuracy.
  static const double _mean = 0.0;
  static const double _std = 255.0;

  /// Number of output classes (APTOS grades 0–4).
  static const int _numClasses = 5;

  /// True once a usable model has been loaded. False when no `.tflite` is
  /// bundled yet — the UI uses this to explain the feature is unavailable.
  bool get isAvailable => _interpreter != null;

  /// Idempotent. Safe to call repeatedly; only the first call loads the model.
  Future<void> load() async {
    if (_triedLoad) return;
    _triedLoad = true;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
    } catch (_) {
      // No model bundled (or it failed to load). Degrade gracefully: the app
      // keeps running and the AI assist stays hidden/disabled.
      _interpreter = null;
    }
  }

  /// Grade the given fundus image bytes.
  ///
  /// Returns null when no model is available or the bytes cannot be decoded —
  /// callers should treat null as "AI unavailable", not "no disease".
  Future<RetinopathyPrediction?> grade(Uint8List imageBytes) async {
    await load();
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final resized =
        img.copyResize(decoded, width: _inputSize, height: _inputSize);

    // Build the [1, H, W, 3] float input tensor.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return <double>[
            (p.r - _mean) / _std,
            (p.g - _mean) / _std,
            (p.b - _mean) / _std,
          ];
        }),
      ),
    );

    // Output: [1, numClasses] class scores.
    final output =
        List.generate(1, (_) => List<double>.filled(_numClasses, 0));
    interpreter.run(input, output);

    return RetinopathyPrediction.fromScores(output.first);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// The five APTOS diabetic-retinopathy grades, in ascending severity.
enum DrGrade {
  noDr('No DR'),
  mild('Mild'),
  moderate('Moderate'),
  severe('Severe'),
  proliferative('Proliferative DR');

  const DrGrade(this.label);

  /// Human-readable label for the UI.
  final String label;
}

/// A single model prediction: the top grade, its confidence, and the full
/// probability distribution (useful to show the health worker the runner-up).
class RetinopathyPrediction {
  RetinopathyPrediction({
    required this.grade,
    required this.confidence,
    required this.scores,
  });

  final DrGrade grade;

  /// Probability of [grade], 0–1.
  final double confidence;

  /// Probability per [DrGrade], same order as [DrGrade.values].
  final List<double> scores;

  factory RetinopathyPrediction.fromScores(List<double> raw) {
    final probs = _asProbabilities(raw);
    var top = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[top]) top = i;
    }
    return RetinopathyPrediction(
      grade: DrGrade.values[top],
      confidence: probs[top],
      scores: probs,
    );
  }

  /// Confidence below which we don't trust the grade and suggest re-screening
  /// instead of a possibly-false reassurance.
  static const double _minConfidence = 0.5;

  /// Map the fine-grained grade to the app's clinical-action enum.
  ///
  /// "Referable DR" = moderate NPDR or worse (grade ≥ 2), the standard
  /// screening threshold. Low confidence maps to [ScreeningResult.ungradable]
  /// (get a human / re-screen) — never a silent "not referable".
  ScreeningResult get suggestedResult {
    if (confidence < _minConfidence) return ScreeningResult.ungradable;
    switch (grade) {
      case DrGrade.noDr:
      case DrGrade.mild:
        return ScreeningResult.notReferable;
      case DrGrade.moderate:
      case DrGrade.severe:
      case DrGrade.proliferative:
        return ScreeningResult.referable;
    }
  }

  /// Treat the raw output as probabilities. If it already looks like a softmax
  /// (non-negative, sums to ~1) use it as-is; otherwise apply softmax to logits.
  static List<double> _asProbabilities(List<double> raw) {
    final sum = raw.fold<double>(0, (a, b) => a + b);
    final allNonNeg = raw.every((v) => v >= 0);
    if (allNonNeg && (sum - 1).abs() < 0.05) return raw;

    final maxV = raw.reduce(math.max);
    final exps = raw.map((v) => math.exp(v - maxV)).toList();
    final expSum = exps.fold<double>(0, (a, b) => a + b);
    return exps.map((e) => e / expSum).toList();
  }
}
