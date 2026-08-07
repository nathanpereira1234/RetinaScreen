import 'package:flutter/foundation.dart';

/// Crash / error reporting (A23).
///
/// Privacy-first: only the error type, its message and the stack trace are
/// recorded — never patient data. Phase 1 ships [LoggingCrashReporter]; swap in
/// a dashboard-backed implementation (e.g. Sentry) via `crashReporterProvider`
/// without touching call sites. See docs/RELEASE.md.
abstract class CrashReporter {
  const CrashReporter();

  /// Record a caught or uncaught error. Never pass patient data in [context].
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  });

  /// Adapter for [FlutterError.onError].
  void recordFlutterError(FlutterErrorDetails details);
}

/// Default reporter: logs via [debugPrint] and pulls in no third-party SDK.
/// Proves the wiring; replace with a real backend before scale (A23 DoD needs a
/// dashboard the forced test crash shows up in).
class LoggingCrashReporter extends CrashReporter {
  const LoggingCrashReporter();

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    recordError(
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {
    debugPrint(
      '[crash]${fatal ? ' FATAL' : ''} ${error.runtimeType}: $error'
      '${context == null ? '' : ' ($context)'}',
    );
    if (stack != null) debugPrint(stack.toString());
  }
}
