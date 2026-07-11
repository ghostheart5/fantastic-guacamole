# Smart Coach Audit

Audit date: 2026-07-11
Scope: Smart Coach intent coverage, response quality, context grounding, follow-up behavior, persistence, and fallback resilience.

## Required Topic Coverage

| # | Topic | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Weight Loss | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 2 | Fatigue | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 3 | Stress | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 4 | Sleep | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 5 | Motivation | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 6 | Focus | PASS | explicit _CoachTopic.focus detection + response templates in state/controllers/coach_query_controller.dart |
| 7 | Procrastination | PASS | explicit _CoachTopic.procrastination detection + response templates in state/controllers/coach_query_controller.dart |
| 8 | Confidence | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 9 | Discipline | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 10 | Habits | PASS | explicit _CoachTopic.habits detection + response templates in state/controllers/coach_query_controller.dart |
| 11 | Nutrition | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 12 | Exercise | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 13 | Burnout | PASS | _detectTopic + _buildStructuredResponse cases in state/controllers/coach_query_controller.dart |
| 14 | Goal Recovery | PASS | explicit _CoachTopic.goalRecovery detection + response templates in state/controllers/coach_query_controller.dart |
| 15 | Future Self | PASS | explicit _CoachTopic.futureSelf detection + response templates in state/controllers/coach_query_controller.dart |
| 16 | Purpose | PASS | explicit _CoachTopic.purpose detection + response templates in state/controllers/coach_query_controller.dart |

## Audit Questions

| Question | Status | Evidence |
| --- | --- | --- |
| Does it detect user intent? | PASS | keyword intent detection in engine/assistant/assistant_detection_service.dart and topic routing in state/controllers/coach_query_controller.dart |
| Does it avoid generic responses? | PASS | structured response contract with Goal Detected / Insight / Actions / Next Step / Coach Question and fallback structure checks in state/controllers/coach_query_controller.dart |
| Does it load user context? | PASS | knowledge and module snapshots include goals, memories, timeline, tasks, progression, core values, soul map in state/controllers/coach_query_controller.dart |
| Does it ask useful follow-up questions? | PASS | topic-specific Coach Question and smart follow-up templates in state/controllers/coach_query_controller.dart and engine/assistant/assistant_response_templates.dart |
| Does it give action steps? | PASS | per-topic action arrays and next-step directives in state/controllers/coach_query_controller.dart |
| Does it save conversation history? | PASS | persisted coach and follow-up turns via saveCoachMessageUseCaseProvider in state/controllers/coach_query_controller.dart |
| Does it support fallback when AI fails? | PASS | safe AI query wrapper + deterministic local fallback response paths in state/controllers/coach_query_controller.dart |

## Summary

- Required topics audited: 16
- Passing topics: 16
- Audit questions: 7
- Passing questions: 7
- Open blockers: 0

## Notes

- Crisis detection remains active through CrisisDetectionPolicy checks before coaching or follow-up processing.
- Follow-up and initial coaching exchanges are now persisted as CoachMessage entities for history continuity.
- Assistant intent detector now includes explicit routing labels for focus, procrastination, habits, goal recovery, future self, and purpose.

## Regression Guardrail

- See SMART_COACH_TEST_MATRIX.md for prompt-level routing, response-shape, fallback, and persistence checks.
