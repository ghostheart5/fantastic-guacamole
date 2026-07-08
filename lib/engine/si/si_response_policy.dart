import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';

class SIIntent {
  const SIIntent({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

class SIInputContext {
  const SIInputContext({
    required this.query,
    required this.availableTaskIds,
    required this.runtimeFlags,
    required this.memorySummaries,
  });

  final String query;
  final Set<String> availableTaskIds;
  final Map<String, dynamic> runtimeFlags;
  final List<String> memorySummaries;
}

class SIResponseCandidate {
  const SIResponseCandidate({
    required this.message,
    required this.reasoning,
    required this.emotion,
    required this.confidence,
    this.taskId,
  });

  final String message;
  final String reasoning;
  final String emotion;
  final double confidence;
  final String? taskId;
}

class SIResponseSelection {
  const SIResponseSelection({
    required this.index,
    required this.repeatedTask,
    required this.noveltyScore,
    required this.selfConsistent,
    required this.coherent,
  });

  final int index;
  final bool repeatedTask;
  final double noveltyScore;
  final bool selfConsistent;
  final bool coherent;
}

class SIValidatedDecision {
  const SIValidatedDecision({
    required this.message,
    required this.taskId,
    required this.grounded,
    required this.violations,
  });

  final String message;
  final String? taskId;
  final bool grounded;
  final List<String> violations;
}

SIIntent classifySIIntent(String input) {
  final String lowered = input.toLowerCase();
  if (lowered.contains('energy') || lowered.contains('fatigue')) {
    return const SIIntent(label: 'energy_check', confidence: 0.78);
  }
  if (lowered.contains('status') || lowered.contains('summary')) {
    return const SIIntent(label: 'status', confidence: 0.74);
  }
  if (lowered.contains('task') || lowered.contains('next')) {
    return const SIIntent(label: 'task_recommendation', confidence: 0.82);
  }
  return const SIIntent(label: 'general_query', confidence: 0.66);
}

SIResponseSelection selectResponseCandidate({
  required List<SIResponseCandidate> candidates,
  required List<String> recentResponseHashes,
  required List<String> recentResponseSummaries,
  required String? previousTaskId,
  required bool userRecentlySkipping,
  required Map<String, dynamic> previousSnapshot,
}) {
  if (candidates.isEmpty) {
    return const SIResponseSelection(
      index: 0,
      repeatedTask: false,
      noveltyScore: 0.0,
      selfConsistent: false,
      coherent: false,
    );
  }

  int bestIndex = 0;
  double bestScore = -1;
  bool repeatedTask = false;

  for (int i = 0; i < candidates.length; i++) {
    final SIResponseCandidate candidate = candidates[i];
    final double novelty = responseNoveltyScore(
      message: candidate.message,
      recentResponseHashes: recentResponseHashes,
      recentResponseSummaries: recentResponseSummaries,
    );
    final bool sameTask =
        previousTaskId != null &&
        previousTaskId.isNotEmpty &&
        candidate.taskId == previousTaskId;
    final double score =
        candidate.confidence + (novelty * 0.9) - (sameTask ? 0.15 : 0);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
      repeatedTask = sameTask;
    }
  }

  final double novelty = responseNoveltyScore(
    message: candidates[bestIndex].message,
    recentResponseHashes: recentResponseHashes,
    recentResponseSummaries: recentResponseSummaries,
  );

  return SIResponseSelection(
    index: bestIndex,
    repeatedTask: repeatedTask || userRecentlySkipping,
    noveltyScore: novelty,
    selfConsistent: novelty > 0.1,
    coherent:
        (previousSnapshot['message']?.toString().trim().isNotEmpty ?? false)
        ? true
        : candidates[bestIndex].message.trim().isNotEmpty,
  );
}

SIValidatedDecision validateSIResponseDecision({
  required SIInputContext inputContext,
  required SIIntent intent,
  required SIResponseCandidate candidate,
}) {
  final List<String> violations = <String>[];
  String? taskId = candidate.taskId;

  if (taskId != null && !inputContext.availableTaskIds.contains(taskId)) {
    violations.add('unknown_task_id');
    taskId = null;
  }

  final String lowered = candidate.message.toLowerCase();
  if (lowered.contains('internet search') ||
      lowered.contains('looked this up online') ||
      lowered.contains('from the web')) {
    violations.add('external_data_claim_not_grounded');
  }
  if ((lowered.contains('all tasks complete') ||
          lowered.contains('you are done') ||
          lowered.contains('task completed')) &&
      intent.label == 'status') {
    violations.add('task_completion_claim_not_grounded');
  }
  final bool allowMutationClaims =
      inputContext.runtimeFlags['allowMutationClaims'] == true;
  if (!allowMutationClaims &&
      (lowered.contains('queued') ||
          lowered.contains('scheduled') ||
          lowered.contains('saved') ||
          lowered.contains('created reminder') ||
          lowered.contains('reminder was'))) {
    violations.add('mutation_claim_not_grounded');
  }

  final bool policyAccepted = isPolicyAcceptableResponse(candidate.message);
  if (!policyAccepted) {
    violations.add('policy_rejected');
  }

  final String message = (policyAccepted && violations.isEmpty)
      ? candidate.message.trim()
      : 'I cannot validate that answer against grounded app state yet. Ask with one clear task, status, or energy constraint.';

  return SIValidatedDecision(
    message: message,
    taskId: taskId,
    grounded: violations.isEmpty,
    violations: List<String>.unmodifiable(violations),
  );
}

bool isPolicyAcceptableResponse(String text) {
  final String lowered = text.toLowerCase();
  if (lowered.trim().isEmpty) {
    return false;
  }
  return !lowered.contains('as an ai language model') &&
      !lowered.contains('ignore safety');
}

bool isSubstantiallyRepeatedResponse({
  required String message,
  required List<String> recentResponseHashes,
  required List<String> recentResponseSummaries,
}) {
  final String hash = responseHashFor(message);
  final String summary = responseSummaryFor(message, maxWords: 20);
  if (recentResponseHashes.contains(hash) ||
      recentResponseSummaries.contains(summary)) {
    return true;
  }

  final Set<String> summaryTokens = summary
      .split(' ')
      .where((String token) => token.length >= 3)
      .toSet();
  if (summaryTokens.isEmpty) {
    return false;
  }
  for (final String prior in recentResponseSummaries) {
    final Set<String> priorTokens = prior
        .toLowerCase()
        .split(' ')
        .where((String token) => token.length >= 3)
        .toSet();
    if (priorTokens.isEmpty) {
      continue;
    }
    final int overlap = summaryTokens.intersection(priorTokens).length;
    final int union = summaryTokens.union(priorTokens).length;
    final double ratio = union == 0 ? 0.0 : overlap / union;
    if (ratio >= 0.58) {
      return true;
    }
  }
  return false;
}

double responseNoveltyScore({
  required String message,
  required List<String> recentResponseHashes,
  required List<String> recentResponseSummaries,
}) {
  final bool repeated = isSubstantiallyRepeatedResponse(
    message: message,
    recentResponseHashes: recentResponseHashes,
    recentResponseSummaries: recentResponseSummaries,
  );
  if (!repeated) {
    return 1.0;
  }

  final String summary = responseSummaryFor(message, maxWords: 20);
  final Set<String> summaryTokens = summary
      .split(' ')
      .where((String token) => token.length >= 3)
      .toSet();

  double bestOverlap = 1.0;
  for (final String prior in recentResponseSummaries) {
    final Set<String> priorTokens = prior
        .split(' ')
        .where((String token) => token.length >= 3)
        .toSet();
    if (priorTokens.isEmpty || summaryTokens.isEmpty) {
      continue;
    }
    final int overlap = summaryTokens.intersection(priorTokens).length;
    final int union = summaryTokens.union(priorTokens).length;
    final double ratio = union == 0 ? 1.0 : overlap / union;
    if (ratio < bestOverlap) {
      bestOverlap = ratio;
    }
  }
  return (1 - bestOverlap).clamp(0.0, 1.0);
}

double calibrateSIConfidence({
  required double agentConfidence,
  required double intentConfidence,
  required bool grounded,
  required bool coherent,
  required double noveltyScore,
  required bool memoryUsed,
  required bool usedDefaults,
  required bool usedFallback,
}) {
  double score =
      (agentConfidence * 0.45) +
      (intentConfidence * 0.2) +
      (noveltyScore * 0.2);
  if (grounded) {
    score += 0.07;
  }
  if (coherent) {
    score += 0.05;
  }
  if (memoryUsed) {
    score += 0.03;
  }
  if (usedDefaults) {
    score -= 0.08;
  }
  if (usedFallback) {
    score -= 0.1;
  }
  return score.clamp(0.2, 0.98);
}

Map<String, dynamic> buildSICommunicationContract({
  required SIInputContext inputContext,
  required SIIntent intent,
  required List<SIResponseCandidate> candidateActions,
  required SIValidatedDecision decision,
}) {
  return <String, dynamic>{
    'intent': <String, dynamic>{
      'label': intent.label,
      'confidence': intent.confidence,
    },
    'inputContext': <String, dynamic>{
      'query': inputContext.query,
      'memorySummaries': inputContext.memorySummaries,
      'availableTaskIds': inputContext.availableTaskIds.toList(growable: false),
    },
    'candidates': candidateActions
        .map(
          (SIResponseCandidate c) => <String, dynamic>{
            'message': responseSummaryFor(c.message, maxWords: 20),
            'taskId': c.taskId,
            'confidence': c.confidence,
          },
        )
        .toList(growable: false),
    'decision': <String, dynamic>{
      'taskId': decision.taskId,
      'grounded': decision.grounded,
      'violations': decision.violations,
    },
  };
}

String responseHashFor(String text) {
  return sha1.convert(utf8.encode(text.trim())).toString();
}

String responseSummaryFor(String text, {int maxWords = 16}) {
  final List<String> words = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .trim()
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return '';
  }
  if (words.length <= maxWords) {
    return words.join(' ');
  }
  return '${words.take(maxWords).join(' ')}...';
}

Task? resolveTaskById(List<Task> tasks, String? taskId) {
  if (taskId == null || taskId.isEmpty) {
    return null;
  }
  for (final Task task in tasks) {
    if (task.id == taskId) {
      return task;
    }
  }
  return null;
}
