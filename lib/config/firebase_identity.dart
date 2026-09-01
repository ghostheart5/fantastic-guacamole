abstract final class FirebaseIdentity {
  static const String expectedProjectId = 'chronospark-app';

  static bool matchesExpectedProjectId(String? projectId) {
    return projectId?.trim() == expectedProjectId;
  }
}
