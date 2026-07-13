# Habit Streak FlowMap

## Trigger
User logs a habit completion or misses a habit check-in window.

## Flow
1. Habit action is submitted from habit UI.
2. Habit provider validates timestamp and habit identity.
3. Habit streak use case computes:
   - current streak
   - best streak
   - streak break condition
4. Habit repository persists updated habit + streak metadata.
5. Progression/insight providers refresh streak-dependent signals.
6. UI updates streak badges, summaries, and warnings.
7. Analytics event is logged.

## Data and Services
- Screen: habits surfaces + summary cards
- Provider/Controller: habits provider/notifier
- Use case: streak update and consistency metrics
- Repository: habit repository
- Data sources: local persistence + optional remote sync
- Services: analytics + reminder service

## Errors
- Missing habit record
- Invalid timestamp ordering
- Persistence failure

## Fallback
- Keep previous streak state and show retry path
- Preserve user action locally for later reconciliation

## Analytics Event
- habit_streak_updated
- habit_streak_broken
- habit_streak_best_reached
