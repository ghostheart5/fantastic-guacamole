function Get-ChronoSparkFatalDiagnosticPatterns {
    # AppObserver.providerDidFail -> Logger.errorCategory emits the detailed
    # first form in debug. Release logging deliberately omits all free-form
    # details, so a code-only categorized ERROR must fail closed: its category
    # cannot be distinguished from a provider failure. Startup hooks emit fatal
    # framework/platform/zone diagnostics at I/flutter in debug and as error
    # codes in release; Android process-crash patterns alone cannot catch them.
    # Detailed unrelated categories and INFO/WARN diagnostics remain nonfatal.
    return @(
        '(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*\[Riverpod Errors\][ \t]*Provider failure\b[^\r\n]*\r?$',
        '(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*\r?$',
        '(?im)^.*(?:\[ERROR\]\[(?:startup\.(?:flutter_framework_error|platform_dispatcher_error|uncaught_zone_error)|error_boundary\.global_error)\](?:[ \t]|\r?$)|(?:FLUTTER_ERROR_MARKER|PLATFORM_ERROR_MARKER)[ \t]+>>>[ \t]*\[ERROR\]).*$',
        '(?im)^.*(?:\bE/flutter(?:[ \t(:])|\bE[ \t]+flutter[ \t]*:).*$'
    )
}
