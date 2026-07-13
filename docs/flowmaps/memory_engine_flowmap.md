# Memory Engine FlowMap

## Trigger
User creates/updates/completes actions that should become memory context.

## Flow
1. Feature event occurs (goal update, task completion, journal note, user preference).
2. Memory capture pipeline creates structured memory:
   - category
   - tags
   - importance
   - metadata
3. Memory linking stage relates memory to similar memories (category/tag/time proximity).
4. Memory is persisted to local repository.
5. Memory summary/search providers refresh.
6. Smart Coach/SI providers consume memory context for personalization.
7. UI surfaces memory in memories screen and nexus dependency mesh.

## Data and Services
- Provider/Controller: memories notifier + memory summary/search providers
- Repository: memory repository
- Data source: local shared prefs/Hive-backed persistence
- Services: analytics/error reporting when available

## Recall Path
1. User query asks for progress/history/context.
2. Memory search/summary providers retrieve relevant memories.
3. Response system injects memory hints into coach/SI output.
4. UI displays contextual response.

## Failure/Fallback
- On malformed stored memory, recover with best-effort parse and continue.
- On write failure, keep in-memory state and report diagnostics.
- On limited memory set, return prompt encouraging structured memory capture.

## Analytics Events
- memory_created
- memory_updated
- memory_archived
- memory_recalled
