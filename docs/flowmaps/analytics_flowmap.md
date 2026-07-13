# Analytics FlowMap

## Trigger
A tracked user/system action occurs in any feature.

## Flow
1. Feature emits analytics track call with event + params.
2. Analytics service checks runtime analytics enablement.
3. Event is logged locally for diagnostics.
4. Event is forwarded to analytics backend.
5. Failures are swallowed to avoid blocking UX.

## Data and Services
- Screen: any feature surface
- Provider/Controller: feature action providers/controllers
- Use case: track analytics event
- Service: AppAnalytics/Firebase analytics bridge
- Data source: runtime state + event payload

## Errors
- Analytics backend unavailable
- Invalid parameter payload

## Fallback
- Continue app flow, keep local diagnostics entry

## Analytics Event
- Feature-specific events (task_completed, coach_opened, etc.)
