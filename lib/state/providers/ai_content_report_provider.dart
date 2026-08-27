import 'package:fantastic_guacamole/data/services/ai/ai_content_report_service.dart';
import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _aiContentReportServiceProvider = Provider<AiContentReportService>((
  Ref ref,
) {
  return AiContentReportService();
});

final aiContentReportActionsProvider = Provider<AiContentReportActions>(
  AiContentReportActions.new,
);

class AiContentReportActions {
  const AiContentReportActions(this._ref);

  final Ref _ref;

  Future<void> submit({
    required String responseText,
    required AiContentReportReason reason,
  }) {
    return _ref
        .read(_aiContentReportServiceProvider)
        .submit(responseText: responseText, reason: reason);
  }
}
