import 'package:fantastic_guacamole/data/services/ai/ai_content_report_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiContentReportServiceProvider = Provider<AiContentReportService>((
  Ref ref,
) {
  return AiContentReportService();
});
