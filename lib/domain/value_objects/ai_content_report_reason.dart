/// CHRONOSPARK-CLASS: SHIPPING | Feature: AI content reporting
enum AiContentReportReason { unsafe, inaccurate, privacy, other }

extension AiContentReportReasonCode on AiContentReportReason {
  String get code => switch (this) {
    AiContentReportReason.unsafe => 'unsafe_or_harmful',
    AiContentReportReason.inaccurate => 'misleading_or_inaccurate',
    AiContentReportReason.privacy => 'privacy_concern',
    AiContentReportReason.other => 'other',
  };
}
