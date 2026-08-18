import '../l10n/labels.dart';
import '../l10n/strings.dart';
import '../models/enums.dart';

/// The patient-facing assistant. Two engines implement this interface:
///
/// - [TemplateAssistant] (default, shipped): fully offline and deterministic —
///   explains a human-entered result in the patient's language. No model, no
///   dependency, always available.
/// - An on-device LLM engine (Gemma-3 1B via `flutter_gemma`) that upgrades it
///   to open Q&A and free translation. It is written up in
///   `docs/LLM_ASSISTANT.md` as a drop-in so the default build can never be
///   broken by a native plugin; enable it on a real device.
///
/// Non-negotiable for BOTH engines: the assistant never grades an image and
/// never gives a diagnosis. It explains a result a human recorded and helps the
/// patient follow up — nothing more. The Gemma prompt in the docs enforces the
/// same scope.
enum AssistantEngine { template, onDevice }

abstract class AssistantService {
  AssistantEngine get engine;

  /// Whether the engine is ready to answer (the template engine always is; the
  /// LLM engine is ready once its model has been downloaded/loaded).
  Future<bool> isReady();

  /// A warm, plain-language explanation of [result] in [strings]' language.
  Future<String> explainResult(AppStrings strings, ScreeningResult result);

  /// Answer a free-form question, scoped to eye-screening follow-up. The
  /// template engine can't reason over open text, so it returns the standard
  /// explanation plus a pointer; the LLM engine answers properly.
  Future<String> ask(
    AppStrings strings,
    ScreeningResult result,
    String question,
  );
}

/// Offline, deterministic assistant. Reuses the localised result copy the app
/// already ships, so there is nothing new to translate and no way for it to
/// wander outside its scope.
class TemplateAssistant implements AssistantService {
  const TemplateAssistant();

  @override
  AssistantEngine get engine => AssistantEngine.template;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<String> explainResult(AppStrings strings, ScreeningResult result) async =>
      spokenResult(strings, result);

  @override
  Future<String> ask(
    AppStrings strings,
    ScreeningResult result,
    String question,
  ) async =>
      '${spokenResult(strings, result)}\n\n${strings.templateModeNote}';
}
