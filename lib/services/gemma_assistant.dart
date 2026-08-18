import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import '../l10n/labels.dart';
import '../l10n/strings.dart';
import '../models/enums.dart';
import 'assistant.dart';

/// On-device LLM assistant (Gemma-3 1B via MediaPipe LiteRT).
///
/// Runs fully on the phone — no PII leaves the device. Scope is locked by the
/// system prompt: it explains a result a human already recorded and helps the
/// patient follow up; it never grades an image or gives a diagnosis.
///
/// The model (~550 MB) is downloaded on demand via [install]; until then the
/// app uses [TemplateAssistant]. The [flutter_gemma] model/chat objects are
/// held as `dynamic` on purpose, so a minor API change in the fast-moving
/// plugin doesn't ripple through the app — see docs/LLM_ASSISTANT.md.
class GemmaAssistant implements AssistantService {
  const GemmaAssistant();

  /// Gemma-3 1B instruction-tuned, int4, LiteRT-LM.
  static const modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  static bool _inited = false;
  static dynamic _model;

  static void _ensureInit() {
    if (_inited) return;
    FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    _inited = true;
  }

  /// Download + install the model, reporting 0–100 progress. Call once (e.g.
  /// from Settings), over Wi-Fi; afterwards it works offline.
  static Future<void> install(void Function(double) onProgress) async {
    _ensureInit();
    await FlutterGemma
        .installModel(modelType: ModelType.gemmaIt)
        .fromNetwork(modelUrl)
        .withProgress((p) => onProgress(p.toDouble()))
        .install();
  }

  static Future<dynamic> _activeModel() async {
    _ensureInit();
    _model ??= await FlutterGemma.getActiveModel(maxTokens: 1024);
    return _model;
  }

  @override
  AssistantEngine get engine => AssistantEngine.onDevice;

  @override
  Future<bool> isReady() async {
    try {
      return (await _activeModel()) != null;
    } catch (_) {
      return false;
    }
  }

  // Hard scope guard — never diagnose, never read images.
  String _system(AppLanguage lang) =>
      'You are a kind assistant for a diabetic eye-screening program. '
      'Reply in simple ${lang.label}, at most 4 sentences. A trained health '
      'worker has ALREADY recorded the screening result — you never diagnose, '
      'never interpret any image, and never contradict the recorded result. '
      'You only explain that result in plain language and help the patient '
      'attend their follow-up. For anything medical beyond that, tell them to '
      'ask their health worker or eye doctor.';

  @override
  Future<String> explainResult(AppStrings s, ScreeningResult result) => _run(
        '${_system(s.language)}\n\nThe recorded result is '
        '"${resultLabel(s, result)}". Explain what it means and the next step.',
      );

  @override
  Future<String> ask(AppStrings s, ScreeningResult result, String question) =>
      _run(
        '${_system(s.language)}\n\nThe recorded result is '
        '"${resultLabel(s, result)}". The patient asks: "$question". '
        'Answer within scope.',
      );

  Future<String> _run(String prompt) async {
    try {
      final model = await _activeModel();
      final chat = await model.createChat();
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      return response.toString().trim();
    } catch (_) {
      return 'The on-device assistant is unavailable right now.';
    }
  }
}
