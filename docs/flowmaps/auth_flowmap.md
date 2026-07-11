# Auth FlowMap

## Trigger
User launches app, signs in, signs up, or restores session.

## Flow
1. Auth gate initializes startup checks.
2. Local/session token state is evaluated.
3. User submits auth action (email/password, provider, or mock path).
4. Auth provider/controller validates input.
5. Auth use case executes.
6. Auth repository performs local/remote auth operations.
7. Result updates auth/session state.
8. UI routes to onboarding or main shell.
9. Analytics/auth events are logged.
10. Auth errors are surfaced with retry/fallback logic.

## Data and Services
- Screen: AuthGate/Login screen
- Provider/Controller: auth controller/provider
- Use case: sign in/up/session restore
- Repository: auth repository
- Data sources: Supabase/Firebase auth + local secure storage
- Services: analytics, crash/error capture

## Errors
- Invalid credentials
- Provider/session token failure
- Network unavailable

## Fallback
- Keep user on auth screen with actionable message
- Offline mode uses cached local state when valid

## Analytics Event
- auth_sign_in_requested
- auth_sign_in_success
- auth_sign_in_failed
