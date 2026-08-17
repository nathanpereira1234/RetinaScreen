import 'package:flutter_tts/flutter_tts.dart';

/// Speaks a patient's result and next step aloud, in their language — for
/// low-literacy field use. Fully on-device; the platform TTS engine renders
/// the audio, nothing is sent anywhere.
///
/// Failures are swallowed (a missing voice for a language should never crash a
/// screening); callers can ignore the returned future.
class TtsService {
  TtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  Future<void> speak(String text, {String languageCode = 'en'}) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(_voiceFor(languageCode));
      await _tts.setSpeechRate(0.44); // slower — clearer for older patients
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    } catch (_) {
      // No voice for this language / engine unavailable — silently no-op.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    _tts.stop();
  }

  /// Map an app language code to a platform TTS locale (India variants).
  static String _voiceFor(String code) => switch (code) {
        'hi' => 'hi-IN',
        'ta' => 'ta-IN',
        _ => 'en-US',
      };
}
