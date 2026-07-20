import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production readiness reports account deletion endpoint issue', () {
    final List<String> issues = Env.productionReadinessIssues(force: true);

    final bool hasDeleteEndpointIssue = issues.any(
      (String issue) => issue.toLowerCase().contains('account deletion endpoint'),
    );

    expect(hasDeleteEndpointIssue, isTrue);
  });

  test('production readiness reports missing or invalid Supabase auth config', () {
    final List<String> issues = Env.productionReadinessIssues(force: true);

    final bool hasSupabaseIssue = issues.any(
      (String issue) => issue.toLowerCase().contains('supabase authentication is not configured') ||
          issue.toLowerCase().contains('supabase url must be a valid https url'),
    );

    expect(hasSupabaseIssue, isTrue);
  });
}
