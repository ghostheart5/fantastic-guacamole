# Smart Planner FlowMap

## Trigger
User submits a planning prompt from Smart Planner screen.

## Flow
1. Smart Planner screen captures text and context inputs (energy, emotion, notes).
2. Planner intent detection classifies request type.
3. Context builder loads:
   - active goals
   - open tasks
   - relevant memory entries
   - recent timeline/log context
4. Planner use case constructs a grounded planning objective.
5. Prompt builder composes structured AI request.
6. AI response generator returns draft response.
7. Response formatter enforces clarity/safety format.
8. UI displays planning response.
9. Conversation event is persisted.
10. Analytics event is logged.

## Data and Services
- Provider/Controller: Smart Planner state + query controller
- Repositories: goals/tasks/memory/log context repositories
- Data sources: Hive local + synced Supabase data where available
- Services: analytics, error boundary/capture, optional TTS output

## Failure/Fallback
- If AI fails, return deterministic fallback planning-guidance text.
- If remote data is unavailable, use local cached context.
- If context load fails, proceed with reduced context and log error.

## Analytics Events
- smart_planner_requested
- smart_planner_response_rendered
- smart_planner_followup_requested
- smart_planner_followup_response_rendered
