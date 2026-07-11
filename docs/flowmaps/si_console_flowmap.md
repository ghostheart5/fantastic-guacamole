# SI Console FlowMap

## Trigger
User submits a natural-language system query in SI Console.

## Flow
1. SI Console screen receives query text.
2. SI intent detection classifies domain and requested output type.
3. Context builder loads:
   - active/overdue tasks
   - goals and drift signals
   - due habits and streak pressure
   - timeline and memory context
4. Priority engine ranks urgency and impact.
5. Recommendation engine computes next best actions.
6. Response formatter generates analysis output with reasons.
7. UI renders answer and supporting rationale.
8. Query/response context is persisted.
9. Analytics event is logged.

## Data and Services
- Provider/Controller: SI console model provider + SI decision provider
- Repositories: tasks/goals/habits/timeline/memory repositories
- Data sources: Hive local, Supabase sync state
- Services: analytics, diagnostics/error logging

## Failure/Fallback
- If inference path fails, return constrained deterministic summary.
- If one source fails, continue with available sources and mark degraded state.
- If all context fails, prompt for narrower command and record fault.

## Analytics Events
- si_console_query_submitted
- si_console_response_rendered
- si_console_degraded_context
