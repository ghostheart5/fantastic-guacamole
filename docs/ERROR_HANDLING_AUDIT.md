# Error Handling Audit

## Error Cases To Handle Cleanly

You need clean handling for:

1. Auth backend unavailable
2. Network unavailable
3. Supabase timeout
4. Firebase init failure
5. Hive box failure
6. AI response failure
7. Invalid input
8. Missing user data
9. Permission denied
10. Subscription failure
11. Notification permission denied

## Every Error Should Have

1. User message
2. Developer log
3. Crashlytics record
4. Retry option
5. Fallback behavior

## Audit Questions

1. ✅ Does each error surface a clear user-facing message?
2. ✅ Is each error logged with enough developer context?
3. ✅ Is each critical failure recorded in Crashlytics?
4. ✅ Is retry available where retry is safe?
5. ✅ Is fallback behavior defined for each critical path?
