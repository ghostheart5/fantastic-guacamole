class SIPolicy {
  const SIPolicy({
    this.safety = true,
    this.tone = 'balanced',
    this.domainRules = const <String>['productivity'],
    this.emotionalRules = const <String>['be_supportive', 'avoid_harshness'],
    this.appConstraints = const <String>[
      'no_destructive_actions_without_confirmation',
    ],
  });

  final bool safety;
  final String tone;
  final List<String> domainRules;
  final List<String> emotionalRules;
  final List<String> appConstraints;
}

class PolicyLayer {
  const PolicyLayer();

  String applyToReply(String reply, SIPolicy policy) {
    if (!policy.safety) return reply;
    final String normalized = reply.trim();
    if (normalized.isEmpty) {
      return 'I am ready when you are.';
    }
    if (policy.tone == 'calm') {
      return normalized;
    }
    return normalized;
  }
}
