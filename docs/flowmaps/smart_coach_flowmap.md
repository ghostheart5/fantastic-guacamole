# Smart Coach FlowMap

## Trigger
User submits a coaching prompt from Smart Coach screen.

## Flow
1. Smart Coach screen captures text and context inputs (energy, emotion, notes).
2. Coach intent detection classifies request type.
3. Context builder loads:
   - active goals
   - open tasks
   - relevant memory entries
   - recent timeline/log context
4. Coach use case constructs a grounded coaching objective.
5. Prompt builder composes structured AI request.
6. AI response generator returns draft response.
7. Response formatter enforces clarity/safety format.
8. UI displays coaching response.
9. Conversation event is persisted.
10. Analytics event is logged.

## Data and Services
- Provider/Controller: smart coach state + query controller
- Repositories: goals/tasks/memory/log context repositories
- Data sources: Hive local + synced Supabase data where available
- Services: analytics, error boundary/capture, optional TTS output

## Failure/Fallback
- If AI fails, return deterministic fallback coaching text.
- If remote data is unavailable, use local cached context.
- If context load fails, proceed with reduced context and log error.

## Analytics Events
- smart_coach_requested
- smart_coach_response_rendered
- smart_coach_followup_requested
- smart_coach_followup_response_rendered
