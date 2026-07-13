# Habits FlowMap

## Trigger
User logs habit progress, updates habit, or checks streak.

## Flow
1. Habit UI captures user action.
2. Habit provider validates and updates record.
3. Habit repository persists latest state.
4. Streak/consistency calculations update.
5. Related insight/progression providers refresh.
6. UI reflects latest streak and status.
7. Analytics logs habit interaction.

## Data and Services
- Screen: Habits-related surfaces/settings
- Provider/Controller: habits provider/notifier
- Use case: save habit record + compute consistency
- Repository: habit repository
- Data sources: local persistence + optional sync
- Services: analytics + reminder orchestration

## Errors
- Habit record write failure
- Reminder sync failure

## Fallback
- Keep local state and retry reminders later

## Analytics Event
- habit_logged
- habit_updated
- habit_streak_updated
