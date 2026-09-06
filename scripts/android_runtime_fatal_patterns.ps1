function Get-ChronoSparkFatalDiagnosticPatterns {
    # AppObserver.providerDidFail -> Logger.errorCategory emits the detailed
    # first form in debug. Release logging deliberately omits all free-form
    # details, so a code-only categorized ERROR must fail closed: its category
    # cannot be distinguished from a provider failure. Detailed unrelated
    # categories and INFO/WARN diagnostics do not match these patterns.
    return @(
        '(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*\[Riverpod Errors\][ \t]*Provider failure\b[^\r\n]*\r?$',
        '(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*\r?$'
    )
}
