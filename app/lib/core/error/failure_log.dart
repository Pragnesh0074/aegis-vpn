import 'package:flutter/foundation.dart';

/// Prints a failure that the UI swallowed.
///
/// Commands run through `AsyncValue.guard`, which is what stops a failed
/// connect from taking the screen down with it — but it also means the only
/// trace of the failure is whatever sentence [describeError] chose. When that
/// sentence is the catch-all, there is nothing left to debug from: the log
/// shows a tap and then silence.
///
/// Debug builds only, and deliberately not routed anywhere off the device. A
/// stack trace from the tunnel path can carry a device id or an endpoint, and
/// this app has no business shipping either to a crash reporter.
void logFailure(String operation, Object error, StackTrace stack) {
  if (!kDebugMode) return;
  debugPrint('[aegis] $operation failed: ${error.runtimeType}: $error');
  debugPrintStack(stackTrace: stack, maxFrames: 12);
}
