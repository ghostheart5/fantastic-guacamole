import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// Returns the device's current time zone identifier, for example
/// `America/Chicago`.
typedef LocalTimezoneNameReader = Future<String> Function();

/// Returns the device's current offset from UTC.
typedef DeviceOffsetReader = Duration Function();

Future<String> _readDeviceTimezoneName() async =>
    (await FlutterTimezone.getLocalTimezone()).identifier;

Duration _readDeviceOffset() => DateTime.now().timeZoneOffset;

/// Points `tz.local` at the device's current time zone.
///
/// Called at startup and at the start of every reminder reconcile so repeating
/// reminders follow a zone change without a restart. When the lookup fails, a
/// fixed-offset zone built from the device's current offset is used instead of
/// silently staying on UTC, and one coded diagnostic is recorded.
///
/// [shouldApply] lets a caller skip the change when its work was cancelled
/// while the lookup was in flight.
Future<void> refreshLocalTimezone({
  LocalTimezoneNameReader readName = _readDeviceTimezoneName,
  DeviceOffsetReader readOffset = _readDeviceOffset,
  bool Function()? shouldApply,
}) async {
  try {
    final String name = await readName();
    if (shouldApply != null && !shouldApply()) return;
    final tz.Location location = tz.getLocation(name);
    tz.setLocalLocation(location);
    RuntimeDiagnostics.record('Timezone configured: $name');
  } on Object {
    if (shouldApply != null && !shouldApply()) return;
    final Duration offset = readOffset();
    tz.setLocalLocation(_fixedOffsetLocation(offset));
    Logger.errorCode(
      code: AppDiagnosticCode.timezoneLookupFailed,
      debugMessage: 'Time zone lookup failed; using the device UTC offset.',
    );
    RuntimeDiagnostics.recordState(
      'timezone.lookup_failed',
      message: 'using the device UTC offset',
      data: <String, Object?>{'offsetMinutes': offset.inMinutes},
    );
  }
}

tz.Location _fixedOffsetLocation(Duration offset) {
  final int minutes = offset.inMinutes;
  final String sign = minutes < 0 ? '-' : '+';
  final int absolute = minutes.abs();
  final String clock =
      '${(absolute ~/ 60).toString().padLeft(2, '0')}:'
      '${(absolute % 60).toString().padLeft(2, '0')}';
  return tz.Location(
    'Fixed/UTC$sign$clock',
    <int>[tz.minTime],
    <int>[0],
    <tz.TimeZone>[
      tz.TimeZone(offset, isDst: false, abbreviation: 'UTC$sign$clock'),
    ],
  );
}
