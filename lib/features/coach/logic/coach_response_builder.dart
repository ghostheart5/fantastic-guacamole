class ResponseBuilder {
  const ResponseBuilder();

  String streakWarningMessage({required bool atRisk}) {
    if (!atRisk) {
      return 'Momentum is stable. Keep showing up.';
    }
    return 'You have not done a session today. Do a quick 5-minute session to keep your streak alive.';
  }
}
