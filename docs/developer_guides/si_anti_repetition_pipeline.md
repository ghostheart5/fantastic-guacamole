<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## Prevent repetitive outputs

Repetitive AI output usually happens when the assistant lacks memory of recent suggestions, has no diversity/ranking stage, or recomputes from the same state without a novelty check.

Anti-repetition tools in this codebase:
- engine/si/si_memory.dart
- engine/si/si_snapshot.dart
- engine/si/si_tiered_memory.dart
- engine/si/si_user_state_tracker.dart
- engine/si/si_self_consistency_engine.dart
- engine/si/si_cognitive_coherence_validator.dart
- engine/learning/learning_history.dart
- engine/learning/adaptive_learning.dart
- engine/optimizer/optimization_merger.dart
- engine/tasks/task_ranker.dart
- core/utils/rate_limiter.dart
- core/utils/throttle.dart

Recommended anti-repetition pipeline:
Candidate generation
  -> similarity check against last N responses
  -> novelty score
  -> task/action cooldown check
  -> self-consistency check
  -> policy check
  -> final response selection

Practical rules:
1. Store recent assistant outputs in SI snapshot memory.
2. Hash or summarize each response for next-turn comparisons.
3. Penalize repeated task recommendations unless task state changed.
4. Use learning history to avoid repeatedly suggesting what the user keeps skipping.
5. Use rate limiter and throttle to suppress repeated prompts and nudges.
6. Use self-consistency engine to select less repetitive, more useful candidates.
7. Use coherence validator to reject responses that drift from current state.

Current implementation hooks:
- state/controllers/ai_controller.dart
- state/models/si_memory_models.dart
- engine/si/si_engine.dart
