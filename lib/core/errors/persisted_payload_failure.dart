import 'package:fantastic_guacamole/core/debug/logger.dart';

/// Records schema/decoding failures without exporting persisted user content.
///
/// Callers must leave the original payload untouched so it remains available
/// for a later recovery or migration. Errors outside the known decoding family
/// are rethrown with their original stack rather than being disguised as an
/// empty or default value.
void handlePersistedPayloadDecodeFailure({
  required String diagnosticCode,
  required Object error,
  required StackTrace stackTrace,
}) {
  if (error is! FormatException &&
      error is! TypeError &&
      error is! ArgumentError &&
      error is! StateError) {
    Error.throwWithStackTrace(error, stackTrace);
  }

  Logger.recordDiagnosticCode(code: diagnosticCode, stackTrace: stackTrace);
}
