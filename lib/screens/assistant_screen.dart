import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// Patient assistant: explains a result in plain language and (with the
/// on-device model enabled) answers open questions. Never diagnoses — it works
/// from a result a human already recorded.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({
    super.key,
    required this.result,
    required this.patientName,
  });

  final ScreeningResult result;
  final String patientName;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _Msg {
  const _Msg(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _messages = <_Msg>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _explain());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _explain() async {
    final s = ref.read(stringsProvider);
    final text =
        await ref.read(assistantServiceProvider).explainResult(s, widget.result);
    if (mounted) setState(() => _messages.add(_Msg(text, fromUser: false)));
  }

  Future<void> _send() async {
    final q = _input.text.trim();
    if (q.isEmpty || _busy) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _messages.add(_Msg(q, fromUser: true));
      _input.clear();
      _busy = true;
    });
    final answer =
        await ref.read(assistantServiceProvider).ask(s, widget.result, q);
    if (mounted) {
      setState(() {
        _messages.add(_Msg(answer, fromUser: false));
        _busy = false;
      });
    }
  }

  void _listen(String text) {
    final lang = ref.read(localeProvider);
    ref.read(ttsServiceProvider).speak(text, languageCode: lang.code);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final onDevice =
        ref.watch(assistantServiceProvider).engine == AssistantEngine.onDevice;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.assistant),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Chip(
                label: Text(onDevice ? 'On-device AI' : 'Standard'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _Bubble(
                message: _messages[i],
                onListen: _listen,
                listenLabel: s.listen,
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: s.askPlaceholder,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: s.send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onListen,
    required this.listenLabel,
  });

  final _Msg message;
  final ValueChanged<String> onListen;
  final String listenLabel;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: fromUser
              ? AppColors.primaryLight
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: fromUser ? Colors.white : null),
            ),
            if (!fromUser)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onListen(message.text),
                  icon: const Icon(Icons.volume_up_outlined, size: 18),
                  label: Text(listenLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
