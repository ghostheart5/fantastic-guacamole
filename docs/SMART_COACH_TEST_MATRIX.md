# Smart Coach Test Matrix

Last updated: 2026-07-11
Purpose: regression guardrail for Smart Coach intent routing, response shape, and fallback behavior.

## How To Use

1. Send each prompt in Smart Coach.
2. Confirm detected topic/intent aligns with expected routing.
3. Confirm response includes the required structure:
   - Goal Detected
   - Insight
   - Actions
   - Next Step
   - Coach Question
4. Confirm at least one actionable step is concrete and immediate.
5. Confirm conversation turn is persisted in coach message history.

## Topic Routing Cases

| Topic | Prompt Example | Expected Topic Route | Expected Intent Label |
| --- | --- | --- | --- |
| Weight Loss | I need to lose weight before next month and I keep snacking at night. | Weight Loss | weight_loss |
| Fatigue | I am exhausted and low energy every afternoon. | Fatigue | energy |
| Stress | Work pressure is crushing me and I feel overwhelmed. | Stress | stress_support |
| Sleep | I keep waking up at 3am and my sleep is bad. | Sleep | sleep |
| Motivation | I cannot start my task and have zero motivation. | Motivation | mindset or productivity |
| Focus | I keep getting distracted and cannot focus for 20 minutes. | Focus | focus |
| Procrastination | I am procrastinating on this one important project. | Procrastination | procrastination |
| Confidence | I do not feel confident presenting to my team. | Confidence | mindset |
| Discipline | I keep breaking my routine and my discipline is weak. | Discipline | mindset |
| Habits | Help me build a habit to journal every morning. | Habits | habit_building |
| Nutrition | My diet is chaotic, I skip protein, and overeat later. | Nutrition | nutrition |
| Exercise | Build me a workout plan I can do today. | Exercise | exercise |
| Burnout | I am burned out and cannot keep pushing like this. | Burnout | stress_support |
| Goal Recovery | I fell behind on my goals and need to get back on track. | Goal Recovery | goal_recovery |
| Future Self | I want to act like my future self starting now. | Future Self | future_self |
| Purpose | I feel disconnected and need clarity on my purpose. | Purpose | purpose |

## Response Quality Checks

| Check | Pass Criteria |
| --- | --- |
| Non-generic response | Response is specific to prompt topic and includes concrete actions. |
| Actionability | At least 3 actions and one immediate next step. |
| Follow-up quality | Coach Question asks for a decision, metric, or commitment. |
| Context grounding | Output references user state where available (energy/emotion/goals/memories/timeline). |
| Safety fallback | If AI path fails, deterministic local response still returns full structure. |

## Follow-Up Cases

| Scenario | Follow-up Prompt | Expected Behavior |
| --- | --- | --- |
| Follow-up after weight loss advice | Current weight is 220 and target is 195. | Follow-up acknowledges numbers and gives a concrete immediate move. |
| Follow-up after stress advice | Main stressor is deadline pressure from work. | Follow-up reflects stress source and narrows to one next step. |
| Follow-up after focus advice | I can only focus for 10 minutes before switching. | Follow-up gives a focus sprint strategy and one commitment question. |
| Follow-up after purpose advice | I do not know what mission to prioritize. | Follow-up provides values-aligned triage and one purpose-defining question. |

## Fallback Cases

| Scenario | Test Method | Expected Result |
| --- | --- | --- |
| AI recommendation returns non-structured text | Inject or simulate unstructured output | Controller returns deterministic structured coaching block. |
| AI provider throws exception | Simulate executeCoachQuery failure path | Controller catches error and returns deterministic local fallback response. |
| Crisis phrase in input | Prompt includes self-harm crisis terms | Crisis policy path is triggered and coaching generation is bypassed. |

## Persistence Checks

| Check | Expected Result |
| --- | --- |
| Initial coaching turn saved | One user and one assistant CoachMessage persisted for coaching request. |
| Follow-up turn saved | One user and one assistant CoachMessage persisted for each follow-up. |
| Empty content not saved | Blank messages are skipped by persistence helper. |

## Coverage Notes

- Intent classifier labels come from engine/assistant/assistant_detection_service.dart.
- Topic routing and deterministic response generation come from state/controllers/coach_query_controller.dart.
- Conversation persistence path uses saveCoachMessageUseCaseProvider via CoachMessage entity.
