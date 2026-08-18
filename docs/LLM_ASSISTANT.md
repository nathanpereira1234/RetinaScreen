# On-device LLM assistant (Gemma-3 1B)

The app ships an offline **Assistant** (Patient detail → the assistant icon on a
screening) backed by `TemplateAssistant` — deterministic, localised, always
available. This guide swaps in a **real on-device LLM** (Gemma-3 1B via
`flutter_gemma` / MediaPipe LiteRT) that adds open Q&A and free translation,
still fully on-device (no PII leaves the phone).

It's kept as a doc — not compiled into the default build — on purpose: a native
ML plugin that fails to build (Gradle, minSdk, native libs) would break the
*whole* app, and it can only really be tested on a device. Enable it there.

**Scope is non-negotiable:** the model only explains a result a human recorded
and helps the patient follow up. It must never grade an image or give a
diagnosis. The system prompt below enforces this — keep it.

---

## 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  flutter_gemma: ^1.5.9
```

`flutter pub get`.

## 2. Android setup

- `android/app/build.gradle` → `minSdkVersion 24` (MediaPipe GenAI needs 24+).
- `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

  ```xml
  <uses-native-library android:name="libOpenCL.so" android:required="false"/>
  ```

Device reality: a 1B int4 model wants ~1.5 GB free RAM and ideally a GPU. It
runs on mid-range phones; on the very cheapest 2 GB devices it will be slow or
refuse to load — which is why the assistant falls back to `TemplateAssistant`.

## 3. Initialise + download the model (once)

In `main()` before `runApp` (or lazily the first time the user opens the
Assistant), initialise and install the model. The `.litertlm` file is ~550 MB;
download it once over Wi-Fi, then it works offline forever.

```dart
FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);

await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
    .fromNetwork(
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
    )
    .withProgress((p) => debugPrint('model $p%'))
    .install();
```

Show the download progress in your UI and gate the assistant on completion.

## 4. The engine (implements the existing `AssistantService`)

Create `lib/services/gemma_assistant.dart`. The whole app is written against
`AssistantService`, so this is the only new code and the provider swap below is
the only wiring change.

```dart
import 'package:flutter_gemma/flutter_gemma.dart';

import '../l10n/labels.dart';
import '../l10n/strings.dart';
import '../models/enums.dart';
import 'assistant.dart';

class GemmaAssistant implements AssistantService {
  @override
  AssistantEngine get engine => AssistantEngine.onDevice;

  @override
  Future<bool> isReady() async {
    try {
      return (await FlutterGemma.getActiveModel(maxTokens: 8)) != null;
    } catch (_) {
      return false;
    }
  }

  // Hard scope guard — never diagnose, never read images.
  String _system(AppLanguage lang) =>
      'You are a kind assistant for a diabetic eye-screening program. '
      'Reply in simple ${lang.label}, at most 4 sentences. '
      'A trained health worker has ALREADY recorded the screening result — you '
      'never diagnose, never interpret any image, and never contradict the '
      'recorded result. You only explain that result in plain language and help '
      'the patient attend their follow-up. If asked anything medical beyond '
      'that, tell them to ask their health worker or eye doctor.';

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
    final model = await FlutterGemma.getActiveModel(maxTokens: 512);
    final chat = await model.createChat();
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final response = await chat.generateChatResponse();
    await model.close();
    // generateChatResponse returns the text (or a response object with a
    // `.token`/`.text` — adjust to your flutter_gemma version if needed).
    return response.toString();
  }
}
```

## 5. Flip the provider

In `lib/providers/app_providers.dart`:

```dart
// was: Provider<AssistantService>((ref) => const TemplateAssistant());
final assistantServiceProvider = Provider<AssistantService>((ref) {
  // Return GemmaAssistant() only once the model is installed; otherwise keep
  // the offline TemplateAssistant so the feature never dead-ends.
  return GemmaAssistant();
});
```

A robust version checks `isReady()` (a `FutureProvider`) and returns
`TemplateAssistant` until the model is downloaded.

## 6. Verify on a device

`flutter run` on a real phone (not an emulator — MediaPipe GenAI needs real
GPU/CPU). Open a patient → a screening → the assistant icon, and ask a free-form
question. If the model isn't installed or the device is too weak, you'll get the
template answer — that's the intended graceful fallback.

> The `flutter_gemma` API moves fast. If `flutter pub get` resolves a version
> whose API differs from the calls above, check the package README and adjust
> `gemma_assistant.dart` only — nothing else in the app depends on it.
