# Notification FlowMap

## Trigger
A reminder, decision nudge, completion feedback, or system alert must be sent.

## Flow
1. Feature/provider requests notification action.
2. Notification provider validates payload + channel/category.
3. Notification service schedules or dispatches local push.
4. Optional mirrored timeline/log entry is created.
5. User receives notification and may open app deep link.
6. Interaction and delivery outcomes are logged.

## Data and Services
- Screen: invoked by multiple features (tasks, coach, sync, etc.)
- Provider/Controller: notification provider/actions
- Use case: schedule/send notification
- Repository: notification state where applicable
- Data sources: local notification plugin + app state
- Services: platform notifications + analytics

## Errors
- Permission denied
- Invalid payload/channel
- Scheduling failure

## Fallback
- Graceful no-op with diagnostic log when permission is off
- Retry schedule on next valid opportunity

## Analytics Event
- notification_scheduled
- notification_sent
- notification_opened
- notification_failed
