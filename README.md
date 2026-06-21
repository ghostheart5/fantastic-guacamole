# fantastic-guacamole
ChronoSpark is the future of life management in every possible way
# ChronoSpark

**ChronoSpark** is a Flutter-based "second brain" productivity and decision-support application designed to act as an intelligent, persistent assistant for task management, time-blocking, adaptive learning, and AI-driven decision-making.

---

## Overview

ChronoSpark combines a beautiful Material 3 UI with a sophisticated behavioral engine to help users:

- **Organize & Execute**: Create tasks, missions, routines, and time-blocked schedules.
- **Learn Adaptively**: Track task behavior (completion patterns, skip/delay rates) and adjust suggestions dynamically.
- **Make Decisions**: Generate AI-powered recommendations for focus, energy management, and workload balancing.
- **Persist Everything**: Store all data locally with automatic synchronization on state changes.
- **Test Premium Features**: Free trial quotas for advanced modules (Temporal Ops & SI Console) before requiring upgrade.

---

## Architecture

### Technology Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider pattern with `ChangeNotifier`
- **Persistence**: `SharedPreferences` via abstracted `RuntimePersistence` layer (designed for future Hive/SQLite upgrades)
- **Typography**: Google Fonts (Orbitron, Inter, etc.)
- **UI Pattern**: Material 3 + custom glassmorphic components

### Core Layers

#### 1. **AppState** (`lib/core/state/app_state.dart`)
Central runtime orchestrator that:
- Maintains `currentState` (energy, workload, deadline pressure, task list)
- Manages missions, routines, logs, decisions, and notifications
- Persists and hydrates all state via `RuntimePersistence`
- Routes console input, time updates, and task lifecycle operations
- Tracks trial quotas for premium features
- Orchestrates `AdaptiveLearningSystem`, `SiEngine`, and `NotificationManager`

**Key Methods**:
- `updateFromConsole()` – Process natural-language-like commands
- `updateFromTime()` – Update state on time changes
- `addTask()`, `editTask()`, `completeTask()`, `skipTask()`, `delayTask()`
- `addMission()`, `addRoutine()`
- `consumeTemporalOpsTrialIfNeeded()`, `consumeSiConsoleTrialIfNeeded()` – Gated access with quota tracking

#### 2. **SI Engine** (`lib/core/si/si_engine.dart`)
Decision-generation engine that:
- Ingests energy, workload, deadline pressure, recent task behavior, and adaptive scores
- Produces `SiDecision` objects with:
  - `primaryDecision` – Main recommended focus
  - `secondaryAction` – Supporting activity
  - `optionalAction` – Lower-priority suggestion
  - `focusTasks` – Top-ranked tasks to prioritize
  - `energy`, `workload` – Normalized state metrics
  - `systemNote` – Explanation for the user
- Consumes `TaskSuggester` for fallback/recommended task generation

#### 3. **Adaptive Learning System** (`lib/core/si/adaptive_learning.dart`)
Behavioral tracking and scoring that:
- Records task completions, skips, delays, and console interactions
- Builds per-task behavior score: completion rate, skip/delay counts, recent engagement
- Tracks active-hour histograms to infer user patterns
- Ranks tasks dynamically based on completion likelihood and user history
- Exports/imports JSON for persistence
- Provides `outputLoadModifier` to reduce suggestion volume when user is overwhelmed

**Key Methods**:
- `registerCompletion()`, `registerSkip()`, `registerDelay()`
- `rankTasks()` – Sort tasks by adaptive score
- `scoreForTask()` – Get numeric score for single task
- `outputLoadModifier` – Reduce load when system detects overwhelm

#### 4. **Task Suggester** (`lib/core/si/task_suggester.dart`)
Fallback task recommendation engine that:
- Generates recommended task lists based on energy, workload, task count, time of day
- Produces fallback tasks when the core task list is thin
- Returns `TaskSuggestionResult` with `recommended`, `fallback`, and system hint

#### 5. **Notification Manager** (`lib/core/system/notification_manager.dart`)
Intelligent notification generation with:
- Typed notifications (completion feedback, energy warnings, deadline alerts, etc.)
- Priority-based cooldown logic
- Response tracking and user engagement scoring
- Activity markers to avoid over-notification
- Automatic throttling to prevent fatigue

#### 6. **Runtime Persistence** (`lib/core/system/runtime_persistence.dart`)
Abstracted persistence layer that:
- Defines `RuntimePersistence` interface
- Implements `SharedPrefsRuntimePersistence` for JSON snapshot storage
- Designed to swap to Hive/SQLite without app-layer changes
- Stores/loads complete state snapshots with schema versioning

---

## Feature Areas

### Shell Navigation (`lib/features/system_shell/`)

The app uses a bottom-nav shell with five main tabs:

1. **Nexus** (`nexus_page.dart`)
   - Home/dashboard
   - Displays current `decision.systemNote`
   - Shows primary, secondary, and optional action cards
   - Portal buttons to jump to other modules
   - Real-time decision feedback

2. **ChronoCreator** (`chronocreator_page.dart`)
   - Task, mission, and routine creation interface
   - Feeds new items directly into AppState
   - Updates adaptive learning and decision engine in real-time

3. **Temporal Ops** (`temporal_ops_page.dart`)
   - Time-blocking and calendar interface
   - Multiple view modes: ChronoFlow (timeline), ArcView (circular), Constellation (task web)
   - Chrono-ring pulse animation and focus-mode visuals
   - Task interaction (create, complete) with live AppState sync
   - Day chips for date navigation
   - **Premium/Trial Feature**: Free 5 test opens; then requires upgrade

4. **SI Console** (`si_console_page.dart`)
   - Text-based console for direct engine interaction
   - Send natural-language commands to `AppState.updateFromConsole()`
   - View decision history and system logs
   - **Premium/Trial Feature**: Free 8 test opens; then requires upgrade

5. **ChronoLogs** (`chronologs_page.dart`)
   - Historical event and decision log viewer
   - Trace past recommendations and user interactions

6. **Settings** (`settings_page.dart`)
   - Paywall and premium access management
   - Link to premium tier benefits

### Premium Gating (`lib/ui/system/premium_feature_gate.dart`)

- **Trial Model**: Temporal Ops (5 free opens) and SI Console (8 free opens)
- **Persistence**: Trial counters stored in runtime snapshot
- **Flow**: When quota exhausted, tab redirects to Settings with upgrade prompt
- **Bypass**: Premium users have unlimited access

---

## UI Components

### Core Components

- **AnimatedSystemBackground** – Parallax background with overlays, glow effects, and error fallbacks
- **GlassPanel** – Glassmorphic card with optional glow overlay
- **SystemHeader** – Top bar with section title and alert count
- **SystemBottomNav** – Custom navigation bar with icon + label items
- **PremiumFeatureGate** – Gate screen for quota-exhausted premium features

### Visual Language

- **Font**: Orbitron (headings), Inter (body, support)
- **Palette**: Purples, teals, dark backgrounds with accent glows
- **Motion**: Smooth transitions, pulse animations, focus-mode dimming
- **Density**: Material 3 spacing and density settings

---

## Data Model

### Core Entities (`lib/core/system/behavior_entities.dart`)

**Current Implementation (v1 active)**:

- **ChronoUserState**: Energy level, workload, deadline pressure, current tasks
- **SiTask**: Title, priority, deadline flag
- **ChronoMission**: Collection of tasks with deadline and importance
- **ChronoRoutine**: Recurring task set
- **ChronoGoal**: Long-term objective
- **ChronoDecision**: AI recommendation output
- **ChronoNotification**: Typed alert with priority, response tracking
- **ChronoLog**: Event record for audit trail
- **ChronoEvent**: Discrete behavioral event

### Time-Block Model (`lib/core/chrono/`)

- **TimeBlock** – Discrete scheduled slot with start/end time, task link, priority
- **CalendarEntry** – Day's collection of time blocks
- **CalendarService** – In-memory date-keyed storage, overlap prevention, sorting
- **ChronoProvider** – Selected date and focus-mode state with listeners

---

## Complete Entity Catalog

### 🔹 A. Core Productivity Entities (v1 Mandatory)

These form the foundation of ChronoSpark's task management:

- **Task** – Title, description, priority, due date, status
- **Project** – Grouping/container for related tasks
- **Plan (Daily/Weekly)** – Structured set of scheduled items for a time period
- **Goal** – Long-term objective with measurable outcome
- **Milestone** – Checkpoint or phase within a goal
- **Routine** – Repeatable structured sequence (e.g., morning routine, daily standup)
- **Habit** – Recurring behavior tracking (e.g., "exercise 3x/week")
- **Subtask** – Breakdown/dependency of a parent task

### 🔹 B. Scheduling & Time Entities

Critical for the SI engine's scheduling logic:

- **Event** – Fixed-time item (meeting, class, appointment)
- **TimeBlock** – Reserved time slot (deep work session, gym, focus time)
- **WorkWindow** – Flexible time slot auto-filled with suitable tasks
- **Reminder** – Alert/notification trigger
- **Deadline** – Time constraint on task or goal completion
- **Duration** – Estimated or actual time spent

### 🔹 C. Intelligence / SI Engine Entities

What makes ChronoSpark "smart":

- **Status** – Energy level, focus capacity, mood (drives scheduling recommendations)
- **Template** – Reusable day/plan structure (e.g., "productive Monday template")
- **Rule** – Conditional logic (IF energy low → schedule easier tasks)
- **Automation** – Trigger + action flow (WHEN 9AM → start focus session)
- **Score / Analytics** – Productivity score, completion rate, consistency metrics
- **Suggestion** – AI-generated task recommendation

### 🔹 D. Organization Entities

For structuring and filtering data:

- **Category** – High-level grouping (Work, Personal, Study, Health)
- **Tag** – Flexible labeling (urgent, waiting, review)
- **Bucket / Board Column** – Kanban-style grouping (Backlog, In Progress, Done)

### 🔹 E. Motivation & Behavioral Entities (Advanced)

These make ChronoSpark unique and engaging:

- **Commitment** – Obligation or pledge (e.g., "exercise 3x/week")
- **Reward** – Incentive or positive reinforcement
- **Note** – Freeform content attached to tasks/projects
- **Session (Focus Session)** – Timed work period with focus state tracking
- **Progress** – Quantified movement toward goal

### 🔹 F. System / Meta Entities

Internal but essential:

- **User Profile** – Account and identity info
- **Preferences** – User settings and customizations
- **Theme / UI Config** – Visual appearance settings
- **Notification Settings** – Alert preferences and cooldown rules
- **Workspace (future)** – Multi-user or multi-device organization

---

## All Create Use Cases

### 🧠 A. Basic Creation Flows

Users can create:

- **Create task** – Title, priority, optional deadline
- **Create project** – Container for related tasks
- **Create goal** – Long-term objective
- **Create plan (daily/weekly)** – Time-scoped task set
- **Create note** – Freeform content
- **Create category** – Organizational grouping

### 🧠 B. Planning & Structuring

Hierarchical creation:

- **Create task inside project** – Assign task to container
- **Break task into subtasks** – Decompose complex work
- **Create milestone under goal** – Phase/checkpoint
- **Assign task to time block** – Schedule in calendar
- **Add task to plan** – Include in daily/weekly plan
- **Create board / bucket** – Kanban column

### 🧠 C. Scheduling (SI-Powered)

Time and calendar operations:

- **Create event (fixed)** – Meeting or appointment
- **Create flexible task (auto-scheduled)** – System suggests optimal time
- **Create recurring habit** – Daily/weekly behavior
- **Create routine template** – Reusable sequence
- **Create time block** – Dedicated focus period
- **Create reminder** – Alert trigger

### 🧠 D. Smart / AI-Assisted Creation

Natural language and recommendations:

- **Create task from natural language** – "Do homework tomorrow at 5pm"
- **Auto-create plan for day** – SI generates optimal daily plan
- **Generate routine from template** – Reuse structure
- **Suggest tasks based on goals** – AI recommends next steps
- **Create adaptive schedule** – Based on energy status

### 🧠 E. Automation & Rules

Conditional logic creation:

- **Create rule** – IF energy low → schedule easier tasks
- **Create automation** – WHEN 9AM → start focus session
- **Create trigger** – Event-driven actions
- **Create recovery plan** – If tasks missed, reschedule intelligently

### 🧠 F. Tracking & Insights

Behavioral logging:

- **Create session** – Focus timer with state tracking
- **Log completed activity** – Record finished task
- **Create analytics snapshot** – Productivity metrics
- **Record behavior** – Completion/skip/delay events

### 🧠 G. Organization & Customization

Meta-level operations:

- **Create tags** – Flexible labeling
- **Create category** – Grouping
- **Create workspace** – Multi-device/multi-user (future)
- **Create theme config** – Visual customization

---

## Entity Relationships

Critical data dependencies:

```
Goal
  ├─ has → Milestones (checkpoints)
  └─ has → Tasks (work items)

Project
  └─ contains → Tasks

Plan (Daily/Weekly)
  ├─ includes → Tasks
  └─ includes → Events

Routine
  └─ generates → Tasks (recurring)

Template
  └─ generates → Plans (from structure)

Status (Energy, Focus, Mood)
  └─ influences → Scheduling decisions

Rule
  └─ modifies → Task scheduling

Task
  ├─ may have → Subtasks
  ├─ may have → Deadline
  └─ may be in → TimeBlock

TimeBlock
  ├─ contains → Tasks
  └─ has → Duration

Decision (SI Output)
  └─ ranks → Tasks (focus order)
```

---

## How ChronoSpark Differentiates

### Unique Create Flows (Beyond Standard Planners)

1. **Create day using energy state** – "I have low energy today" → system generates suitable plan
2. **Create adaptive schedule** – Schedule adjusts in real-time based on task completion rates
3. **Create AI-suggested tasks** – System proposes next logical step based on goals and history
4. **Create recovery plan if missed tasks** – Intelligently reschedule when user falls behind
5. **Create focused session** – Timed work block with state-aware task suggestions

### SI Engine Integration Points

- Status-aware scheduling: Rules and templates use energy/focus/mood as inputs
- Behavioral learning: System adapts suggestions based on task completion patterns
- Adaptive load: Reduces suggestion volume when overwhelm detected
- Contextual ranking: Tasks ordered by energy requirement and deadline proximity
- Automated recovery: Failed/skipped tasks automatically rescheduled

---

## Creation API Reference

For future backend or internal referencing:

```
POST /tasks
POST /projects
POST /goals
POST /milestones
POST /plans
POST /events
POST /time-blocks
POST /habits
POST /routines
POST /templates
POST /rules
POST /automations
POST /sessions
POST /notes
POST /categories
POST /tags
```

---

## Mental Model: How It All Fits

```
User Creates → Items (tasks, goals, routines)
       ↓
Items → Organized into Plans & Projects
       ↓
Plans → Scored & Scheduled by SI Engine
       ↓
Engine Observes → Status (energy, mood, focus)
       ↓
Engine + Rules → Adapt Scheduling & Suggestions
       ↓
User Completes → Behavior Recorded
       ↓
Loop → Learning accumulates, suggestions improve
```

This creates a living, adaptive productivity system that learns and evolves with user behavior.

---

## State Persistence

### Snapshot Structure

AppState persists a JSON snapshot via `RuntimePersistence`:

```json
{
  "schemaVersion": 2,
  "tasks": [...],
  "energy": 0,
  "workload": 0.5,
  "deadlinePressure": 0.6,
  "history": [...],
  "missions": [...],
  "routines": [...],
  "logs": [...],
  "decisionCache": [...],
  "completedTaskTitles": [...],
  "skippedTaskTitles": [...],
  "delayedTaskTitles": [...],
  "temporalTrialUses": 2,
  "siConsoleTrialUses": 5,
  "learning": {...},
  "notifications": [...]
}
```

- **Auto-save** on state changes, console input, task lifecycle, time updates
- **Hydration** on app startup
- **Schema version** enables future migrations

---

## Workflow

### Typical Session

1. **Launch** → App hydrates state from persistence → Decision engine generates initial recommendation
2. **User Opens Tab** → If premium module with remaining trial, consume one use and allow access; otherwise gate to upgrade
3. **User Adds Task** → AppState adds to task list, triggers learning update, recomputes decision
4. **User Completes Task** → Registered in adaptive system, learning score updated, notification emitted
5. **Console Command** → Natural-language-like input parsed, state/task properties updated
6. **Auto-Save** → Any state change persists snapshot
7. **Decision Update** → Hourly or event-driven recompute of SI Engine output
8. **Notifications** → Generated based on priority + user engagement, throttled by cooldown

---

## Premium Features & Trial Model

| Feature | Free Trial | Premium |
|---------|-----------|---------|
| **Nexus** | Unlimited | Unlimited |
| **ChronoCreator** | Unlimited | Unlimited |
| **ChronoLogs** | Unlimited | Unlimited |
| **Temporal Ops** | 5 opens | Unlimited |
| **SI Console** | 8 opens | Unlimited |

### Trial Quota Logic

- Trial counters are **per-install**, stored in local persistence
- Quota consumed on **each tab open** (not per command)
- When exhausted, user is redirected to Settings with a clear upgrade prompt
- Premium users bypass all quotas (trial counters ignored)

---

## Configuration & Asset Management

### Assets

- `assets/backgrounds/` – Main and alternative backgrounds
- `assets/glows/` – Glow overlays for UI elements
- `assets/overlays/` – Visual effect overlays
- `assets/data/` – Static data files

All assets are bundled via `pubspec.yaml` with directory-level inclusion. Image loads include error fallbacks to prevent crash on missing assets.

### Dependencies

- `flutter` – Core framework
- `provider` – State management
- `shared_preferences` – Local persistence
- `google_fonts` – Typography
- `material_color_utilities` – Color utilities

---

## Development Notes

### Key Design Decisions

1. **Abstracted Persistence**: `RuntimePersistence` interface allows swapping from SharedPreferences to Hive/SQLite without app-layer rewrites.
2. **Behavioral Learning Separation**: `AdaptiveLearningSystem` is independent, making engine predictions testable and explainable.
3. **Free Trial Model**: Rather than a strict premium gate, trial quotas allow users to test features before committing to upgrade.
4. **Async Navigation**: Tab opening uses async methods to safely consume trial quotas and check premium access before rendering.
5. **Error Resilience**: Asset loads use `errorBuilder` fallbacks to prevent crashes from stale bundle state.

### Debugging & Analysis

- **Analyzer**: Run `flutter analyze` (currently clean)
- **Testing**: AppState logic can be tested in isolation; SI Engine, learning, and suggestions are pure functions
- **Logging**: Console output and decision cache provide audit trails

---

---

## ChronoLogs: Event & Action Recording System

**ChronoLogs** is ChronoSpark's observability and auditability layer—a comprehensive logging system that records every meaningful user action, system event, and behavioral signal for insight, replay, and compliance.

### Core Philosophy

```
Everything = Event → Stored as Log → Used for Insight
```

Every action a user takes (create task, complete task, open tab) and every system event (decision generated, notification sent, error occurred) becomes a timestamped log entry. These logs serve as:
- **Audit trail** – Who did what, when, where
- **Behavioral dataset** – Pattern recognition and learning
- **Replay capability** – "Life Replay" to see day's actions
- **Analytics foundation** – Productivity metrics and insights

---

### Logging Entities

#### A. Primary Logging Model

**LogEntry** – The fundamental unit of ChronoLogs

Fields:
- `id` – Unique identifier
- `timestamp` – When event occurred
- `actor` – User or system
- `action` – Event type (e.g., task_created, task_completed)
- `entity` – What was affected (task, mission, routine)
- `metadata` – Rich context (task title, priority, duration)
- `status` – Success/failure outcome
- `source` – Device/app origin

**Event** – Meaningful point-in-time action

Examples:
- `login` – User authentication
- `task_created` – New task added
- `task_completed` – Task finished
- `file_updated` – Data modified
- `session_started` – Focus session begun
- `decision_generated` – SI engine output
- `error_occurred` – System failure

**Actor** – Who triggered the log

- User (direct action)
- System (automated event)
- AI agent (SI engine decision)
- External API (integration event)

**Resource/Object** – What was affected

- Task, Project, Mission, Routine, Goal
- TimeBlock, Plan, Session
- Setting, Preference, Rule

#### B. User Behavior Entities

**Session** – Group of related actions in a time window

- Focus session duration
- Session quality score
- Actions performed during session

**Activity Stream** – Timeline of logs for a user or system

**Interaction** – Granular user action

- `click` – UI button/element
- `open` – Tab or feature access
- `edit` – Data modification
- `scroll` – Navigation
- `focus` – Window/input focus

#### C. System-Level Logging

**LogType** – Category of log

- `access_log` – Who accessed what
- `error_log` – System failures
- `audit_log` – Compliance tracking
- `transaction_log` – Data changes
- `debug_log` – Dev troubleshooting
- `performance_log` – System metrics

**Severity/Level** – Log urgency

- `INFO` – General information
- `WARNING` – Potential issue
- `ERROR` – Operation failure
- `CRITICAL` – System-level failure

**Tag/Category** – Organizational label

- "security", "productivity", "navigation", "performance"

#### D. Analytics & Insight Entities

**Metric** – Derived data point

- Time spent on task
- Frequency of action
- Success rate
- Completion rate

**Pattern/Insight** – Behavioral trend

- Peak activity time
- Task completion distribution
- Energy correlation with task type
- Most frequent task category

**Funnel/Flow** – Sequence of actions

- Task creation → Scheduling → Completion
- Decision viewing → Task selection → Execution

#### E. Audit & Compliance

**AuditLog** – Immutable log for compliance

**ChangeRecord** – Before/after values

- Old state and new state
- Change delta
- Change reason

**Trace** – Chain of related events

- Causality link (this event triggered that event)

#### F. Monitoring & Alerting

**Alert** – Triggered on anomaly or condition

- Anomaly detection (unusual pattern)
- Threshold breach (missed 5 tasks)
- System alert (error spike)

**Rule** – Condition that triggers logging/alerting

- `IF failed_attempts > 3 → alert`
- `IF energy_low AND urgent_task → log as struggle`

#### G. Storage & Control

**LogStream** – Real-time ingestion and processing

**RetentionPolicy** – Data lifecycle management

- How long to retain full logs
- Archive old data
- Purge sensitive logs after period

---

### ChronoLogs Create Use Cases

#### A. Automatic Logging (System-Driven)

Core flows that create logs automatically:

- **Create log on user action** – Every CRUD operation (create, read, update, delete)
- **Create log on data change** – Task status, priority, deadline modification
- **Create log on error** – Exceptions, validation failures, system faults
- **Create log on system event** – Decision generated, notification sent, sync completed
- **Create log on navigation** – Tab open, page transition, feature access

#### B. User Activity Tracking

Behavioral capture:

- **Create user session** – Start focus session, track duration
- **Create interaction log** – UI clicks, opens, edits
- **Track navigation path** – Feature usage sequence
- **Track time spent** – Per task, per project, per day
- **Log energy state** – Periodic status capture

#### C. Audit & Compliance

Data governance:

- **Create audit log on authentication** – Login/logout, password change
- **Create audit log on permission change** – Access level modifications
- **Create audit log on data deletion** – Permanent removals with recovery option
- **Create change record** – Before/after values for sensitive changes

#### D. Time & Productivity Tracking

Insights generation:

- **Create activity log** – Time allocation across tasks
- **Create session record** – Focus session with quality metrics
- **Create work log** – Task duration and progress
- **Create productivity snapshot** – Daily score based on logs

#### E. System Monitoring

Operational health:

- **Create error log** – Exceptions with stack trace
- **Create performance log** – Response times, memory usage
- **Create availability event** – Feature uptime/downtime
- **Create transaction log** – State changes with rollback support

#### F. AI / Insight Creation

Learning and analysis:

- **Create behavior pattern** – Recurring habit from logs (e.g., "always completes tasks at 9PM")
- **Create anomaly detection** – Unusual deviation from pattern
- **Create recommendation** – AI suggestion based on historical logs
- **Create productivity insight** – Peak hours, best task types, energy patterns

#### G. Security Tracking

Safety and compliance:

- **Log authentication attempt** – Success/failure
- **Log failed access attempts** – Permission denials
- **Log suspicious activity** – Rapid repeated actions, bulk deletions
- **Log data access** – Who accessed what when

#### H. Analytics Use Cases

User understanding:

- **Create user cohort** – Segment users by behavior
- **Create user journey** – Task creation → scheduling → completion path
- **Create funnel tracking** – Drop-off points in workflows
- **Create engagement heatmap** – Feature usage intensity

#### I. Custom Logging

User-defined capture:

- **Create custom event type** – User-named events
- **Create manual log entry** – Freeform notes with timestamp
- **Create tagged logs** – Flexible categorization

---

### ChronoLogs API Reference

```
POST /logs                 # Create log entry
POST /events              # Create event
POST /sessions            # Create session record
POST /interactions        # Create interaction log
POST /audit-logs          # Create audit entry
POST /change-records      # Create before/after record
POST /alerts              # Create alert
POST /rules               # Create alert rule
POST /metrics             # Create computed metric
POST /patterns            # Create insight pattern
POST /funnels             # Create funnel tracking
POST /log-types           # Define custom log type
POST /tags                # Create organizational tag
```

---

### Entity Relationships

Critical dependencies in ChronoLogs:

```
Actor → performs → Event
Event → creates → LogEntry
LogEntry → belongs to → Session
LogEntry → affects → Resource (Task/Project/etc)
Logs (collection) → grouped into → ActivityStream
Logs (collection) → analyzed into → Metrics / Patterns
Metrics → trigger → Alerts
Alerts → matched against → Rules
Trace → links → causally related Events
```

---

### ChronoSpark vs ChronoLogs

| Aspect | ChronoSpark | ChronoLogs |
|--------|-------------|-----------|
| **Focus** | Create & plan tasks | Record & analyze actions |
| **Direction** | Forward-looking | Backward-looking |
| **Core Engine** | Scheduling + AI decisions | Observability + insights |
| **Purpose** | Help user execute | Help user understand |
| **Data Flow** | User intent → recommendations | Actions → patterns → insights |
| **Time Horizon** | Tomorrow's tasks | Yesterday's behavior |

---

### Unique ChronoLogs Features

#### "Life Replay"
Rewatch your day chronologically:
- Timeline of all actions, decisions, task completions
- Jump to any moment and see full context
- Understand decision-making and execution flow

#### "Behavior Score"
Productivity rating based on:
- Task completion rate
- Session consistency
- Energy management
- Focus quality
- Recovery speed (rescheduling after missed tasks)

#### "Distraction Detection"
From interaction logs:
- Rapid tab switching
- High app context-switching
- Incomplete focus sessions
- Task abandonment patterns

#### "Focus Heatmap"
Visual representation of:
- Best focus hours
- Task type by hour
- Energy correlation with time
- Peak productivity zones

#### "Recovery Intelligence"
Automatic analysis:
- When you typically miss tasks
- What circumstances lead to delays
- Suggested adjustments for consistency
- Predictive intervention before failure

---

### ChronoLogs Mental Model

```
User Action → Event Created → LogEntry Stored
    ↓
LogEntries → Chronologically Organized
    ↓
Logs → Analyzed → Metrics / Patterns Extracted
    ↓
Patterns → Trigger → Alerts / Insights
    ↓
Insights → Feed Back → SI Engine Recommendations
```

This creates a complete **observability loop**: every action is captured, analyzed, and used to improve future recommendations.

---

---

## ChronoSettings: User Preferences & System Configuration

**ChronoSettings** is ChronoSpark's control and personalization layer—a comprehensive settings system that enables users and administrators to customize behavior, manage security, control notifications, and configure integrations without requiring code changes.

### Core Philosophy

```
Settings = Control Layer

User/Admin → change settings
Settings → modify system behavior
System → adapts without code change
```

Every aspect of ChronoSpark's behavior—from UI appearance to scheduling rules to logging frequency—can be controlled through settings. This decouples configuration from code and enables dynamic experimentation and user customization.

---

### Settings Entities

#### A. Core Settings Model

**SettingDefinition** – Blueprint of a setting

Fields:
- `id` – Unique identifier
- `name` – Setting name
- `description` – Human-readable explanation
- `dataType` – boolean, string, enum, number, object
- `defaultValue` – Factory default

**SettingValue** – Actual applied value

Fields:
- `userValue` – User override
- `appValue` – Application default
- `systemValue` – System/admin enforcement
- `effectiveValue` – Which layer wins (user > app > system)

**SettingScope** – Where setting applies

- `Global` – All users, all devices
- `Organization` – Team/workspace level (future)
- `User` – Individual user only
- `Device` – This device only
- `Feature` – Affects specific module

#### B. User Settings & Preferences

**UserPreferences** – Core personalization

- `theme` – dark/light/auto
- `language` – Language code (en, es, fr, etc.)
- `timezone` – User timezone for scheduling
- `layout` – Density, sidebar collapse, card style
- `accentColor` – Primary UI color override

**ProfileSettings** – User identity

- `displayName` – User name
- `avatar` – Profile picture
- `bio` – Short description
- `email` – Contact email

**NotificationSettings** – Alert preferences

- `enablePushNotifications` – In-app alerts
- `enableEmailAlerts` – Email notifications
- `notificationFrequency` – Instant/daily/weekly digest
- `notificationChannels` – Which channels to use
- `quietHours` – Time-based suppression (9PM-8AM)
- `priorityFilter` – Minimum priority to show

**PrivacySettings** – Data sharing

- `visibility` – Public/private/friends-only
- `allowDataShare` – Analytics opt-in
- `allowTracking` – Usage tracking consent
- `shareActivityWith` – Who sees activity

#### C. Security & Access

**SecuritySettings** – Authentication & safety

- `passwordPolicy` – Complexity requirements
- `enableTwoFactor` – 2FA requirement
- `sessionTimeout` – Auto-logout duration
- `loginAttemptLimit` – Failed login threshold
- `trustedDevices` – Skip 2FA on known devices

**PermissionSettings** – Access control

- `role` – User role (admin, user, guest)
- `featureAccess` – Which features user can access
- `dataAccess` – Visibility into other users' data
- `adminCapabilities` – Elevated permissions

**AuthenticationSettings** – Login methods

- `loginMethods` – Email, biometric, OAuth, SSO
- `oauthProviders` – Enabled OAuth services
- `sessionTokenExpiry` – Token validity duration

#### D. System & App Configuration

**FeatureFlag** – Dynamic feature control

- `featureName` – Identifier (e.g., "betaTemporalOps")
- `enabled` – On/off state
- `rolloutPercentage` – Gradual rollout (10%, 50%, 100%)
- `targetUsers` – Specific users to include/exclude

**AppSettings** – Core behavior

- `autoSaveInterval` – How often to persist state (ms)
- `decisionRefreshInterval` – SI engine re-evaluation frequency
- `suggestionAggressiveness` – How many suggestions to show
- `focusSessionDuration` – Default focus time (minutes)

**EnvironmentSettings** – Deployment config

- `environment` – dev/staging/production
- `apiEndpoint` – Backend server URL
- `debugMode` – Enable verbose logging
- `offlineMode` – Local-only operation

**PerformanceSettings** – Optimization

- `enableCaching` – Cache recent data
- `maxConcurrentRequests` – Throttle parallel ops
- `imageCacheSize` – Memory for images (MB)
- `animationDuration` – UI motion speed

#### E. Integration & External

**APISettings** – Third-party integration

- `apiKeys` – Encrypted credential store
- `endpoints` – Service URLs
- `rateLimits` – Request throttling per service
- `timeout` – HTTP request timeout (seconds)

**IntegrationSettings** – Service connections

- `slackWorkspace` – Slack API token
- `emailProvider` – SMTP settings
- `calendarSync` – Google/Outlook sync enabled
- `webhookUrl` – Callback endpoint for events

#### F. Logging & Audit

**LoggingSettings** – Event capture

- `logLevel` – INFO/WARNING/ERROR/DEBUG
- `enableEventLogging` – Capture all events
- `logRetentionDays` – How long to keep logs (days)
- `logEventTypes` – Which events to log (task_created, session_started, etc.)

**AuditSettings** – Compliance tracking

- `enableAuditTrail` – Immutable audit logging
- `trackDataChanges` – Log before/after values
- `trackAccessAttempts` – Log who accessed what
- `compliancePolicy` – GDPR/HIPAA/SOC2 mode

#### G. Device & System

**DeviceSettings** – OS-level config

- `osPermissions` – Microphone, camera, location access
- `storageLocation` – Where to store data locally
- `backupFrequency` – Auto-backup interval

**NetworkSettings** – Connectivity

- `vpnRequired` – Enforce VPN on certain features
- `syncOnCellular` – Allow data sync on mobile data
- `offlineCapability` – Support offline mode

#### H. Advanced / Enterprise

**ConfigurationPolicy** – Admin-enforced settings

- `policyName` – Policy identifier
- `targetGroups` – Which users/teams affected
- `settings` – Locked settings map
- `overrideUserChoice` – Whether user can override

**SettingVersion** – Change history

- `versionNumber` – For rollback support
- `timestamp` – When setting changed
- `changedBy` – Who made change
- `reason` – Why changed

**SettingAuditLog** – Settings audit trail

- `id` – Log entry ID
- `settingName` – Which setting changed
- `oldValue` – Previous value
- `newValue` – New value
- `changedBy` – User/admin who changed it
- `timestamp` – When changed
- `reason` – Change rationale

---

### ChronoSettings Use Cases

#### A. Basic Settings Operations

- **View settings** – Display current configuration
- **Create new setting** – Admin defines new setting type
- **Update setting** – Change value
- **Reset to default** – Revert to factory setting
- **Copy settings** – Apply one user's settings to another

#### B. User Personalization

- **Change theme** – Switch dark/light
- **Change language** – Select UI language
- **Adjust layout** – Density, font size, sidebar position
- **Save preferences** – Persist UI state
- **Customize colors** – Theme customization

#### C. Notification Control

- **Enable/disable notifications** – Toggle alerts
- **Set delivery frequency** – Instant/daily/weekly
- **Choose channels** – Email, push, in-app
- **Set quiet hours** – No alerts during sleep
- **Filter by priority** – Only show important alerts

#### D. Security Management

- **Change password** – Update credentials
- **Enable 2FA** – Add two-factor authentication
- **Manage sessions** – View and terminate active sessions
- **Configure access control** – Set role-based permissions
- **Review login history** – See authentication events

#### E. Feature Control (Admin)

- **Enable feature** – Activate new feature for user
- **Disable feature** – Hide experimental feature
- **Roll out experiment** – Gradual feature rollout
- **A/B test** – Different settings for cohorts
- **Override feature** – Admin force-enable/disable

#### F. System Configuration (Dev/Admin)

- **Configure app behavior** – Set SI engine parameters
- **Set defaults** – Factory defaults per user type
- **Override defaults** – User/app/system layering
- **Tune performance** – Memory, caching, throttling
- **Define policies** – Organization-wide settings

#### G. Organization & Governance

- **Define global settings** – Company-wide configuration
- **Push policies to users** – Enforce restricted settings
- **Lock sensitive settings** – Prevent user override
- **Audit policy compliance** – Track adherence
- **Create user groups** – Apply settings to cohorts

#### H. Logging & Audit

- **Enable logging** – Activate event capture
- **Choose logged events** – Configure granularity
- **Set log retention** – How long to store
- **Review audit trail** – Who changed what when
- **Export logs** – Compliance reporting

#### I. Integration Management

- **Add API key** – Connect external service
- **Configure webhook** – Receive events
- **Set rate limits** – Control API usage
- **Enable OAuth** – Third-party authentication
- **Sync data** – Calendar/email integration

#### J. Performance Tuning

- **Adjust caching** – Trade memory for speed
- **Set refresh intervals** – How often to update
- **Tune suggestion load** – How many recommendations
- **Control animation speed** – UI responsiveness

#### K. Recovery & Safety

- **Reset to default** – Clear all customization
- **Rollback version** – Revert to previous setting state
- **Backup configs** – Export settings
- **Restore configs** – Import settings

---

### ChronoSettings Module Structure

```
Settings
  ├── Profile
  │   ├── Display Name / Avatar
  │   ├── Email
  │   └── Bio
  ├── Preferences
  │   ├── Theme & Layout
  │   ├── Language & Timezone
  │   └── Density & Colors
  ├── Notifications
  │   ├── Channels
  │   ├── Frequency
  │   ├── Quiet Hours
  │   └── Priority Filter
  ├── Privacy
  │   ├── Visibility
  │   ├── Data Sharing
  │   └── Tracking Consent
  ├── Security
  │   ├── Password
  │   ├── 2FA
  │   ├── Sessions
  │   └── Device Trust
  ├── Features & Experiments
  │   ├── Feature Flags
  │   ├── Beta Programs
  │   └── A/B Tests
  ├── System & Performance
  │   ├── App Behavior
  │   ├── Caching
  │   ├── Refresh Intervals
  │   └── Animation Speed
  ├── Integrations
  │   ├── API Keys
  │   ├── OAuth Providers
  │   ├── Webhooks
  │   └── Service Connections
  ├── Logging & Audit
  │   ├── Log Level
  │   ├── Event Types
  │   ├── Retention
  │   └── Audit Trail
  └── Admin / Organization
      ├── Policies
      ├── User Groups
      ├── Compliance
      └── Audit Logs
```

---

### ChronoSettings API Reference

```
GET /settings                    # List all settings
GET /settings/:key               # Get single setting
POST /settings/:key              # Update setting
PUT /settings/:key               # Replace setting
DELETE /settings/:key            # Reset to default
POST /settings/batch             # Update multiple settings

GET /preferences                 # Get user preferences
POST /preferences                # Save preferences

POST /notifications/settings     # Configure alerts
POST /privacy/settings           # Privacy controls
POST /security/settings          # Security config
POST /features/flags             # Feature flag management

POST /integrations/add           # Connect service
DELETE /integrations/:id         # Disconnect service

GET /settings/audit              # View settings changes
POST /settings/rollback          # Revert to version

POST /policies                   # Create policy (admin)
POST /policies/apply             # Apply to users
```

---

### Entity Relationships

```
SettingDefinition
  → defines → SettingValue
  → belongs to → SettingScope

User
  → has → UserPreferences
  → has → NotificationSettings
  → has → SecuritySettings
  → has → PrivacySettings

FeatureFlag
  → controls → AppBehavior

ConfigurationPolicy
  → overrides → UserSettings
  → applied to → UserGroups

SettingChange
  → logged in → SettingAuditLog
  → affects → SystemBehavior

IntegrationSettings
  → enables → ExternalServices
```

---

### ChronoSpark Ecosystem Integration

The three core systems work together:

```
ChronoSpark (Planning)
  ├─ creates & schedules tasks
  ├─ generates recommendations
  └─ executes decisions

ChronoLogs (Observability)
  ├─ records every action
  ├─ analyzes behavior patterns
  └─ provides replay & insights

ChronoSettings (Control)
  ├─ configures planning rules
  ├─ controls logging granularity
  └─ personalizes user experience

Feedback Loop:
  Logs → Patterns → Settings Tuning → Better Plans
```

**Example Flow**:
1. **ChronoSpark** generates focus recommendation
2. **ChronoLogs** records user's response (accepted/ignored)
3. **ChronoSettings** stores user's notification preference
4. **ChronoSpark** adapts future suggestions based on user's settings

---

### Unique ChronoSettings Features

#### "Smart Defaults"
- System learns from behavior, suggests optimal settings
- "You tend to focus best 9-11AM. Use that as default focus window?"
- Propose caching settings based on device capability

#### "Settings Profiles"
- Pre-built configurations for different use cases
- "Productivity Mode" – aggressive suggestions, frequent logging
- "Relaxed Mode" – minimal notifications, minimal logging
- "Deep Work Mode" – disable all interruptions

#### "Adaptive Logging"
- Automatically adjust log verbosity based on system load
- High error rate → increase debug logging
- User overwhelmed → reduce logging overhead

#### "Permission Inheritance"
- Feature access cascades through hierarchy
- Admin enables "Temporal Ops" → inherited by all users
- User can request override with audit trail

#### "Setting Sync Across Devices" (Future)
- Same preferences on desktop, mobile, tablet
- Cloud-backed setting synchronization
- Conflict resolution for changes made simultaneously

---

## SI Console: Natural Language Command Interface

**SI Console** is ChronoSpark's intelligent command interface—a text-based console that accepts both structured commands and natural language input to control planning, query logs, and modify settings. It bridges user intent with system execution through an AI-powered parser that understands context and learns from interaction patterns.

### Core Philosophy

```
Console = Brain Interface

User → types → Command/Natural Language
System → interprets → Intent
Engine → executes → Action
Result → displayed + logged
```

The SI Console serves as a direct, conversational interface to ChronoSpark's planning engine, combining traditional CLI usability with AI-powered natural language understanding.

---

### Console Entities

#### A. Core Command System

**Command** – Executable action blueprint

Fields:
- `name` – Identifier (e.g., "create", "list", "schedule")
- `description` – Human-readable purpose
- `syntax` – Argument format
- `actionMapping` – Handler function

Examples:
- `task create` – Create new task
- `task list` – Show all tasks
- `task complete` – Mark task done
- `schedule today` – Show today's plan
- `log review` – View recent logs

**Subcommand** – Hierarchical command grouping

Examples:
- `task create` (subcommand under `task`)
- `mission add` (subcommand under `mission`)
- `setting change` (subcommand under `setting`)

**Argument** – Required input values

Examples:
- `task create "Do homework"` – "Do homework" is argument
- `task delay "Workout" "2 hours"` – Two arguments

**Option/Flag** – Behavioral modifiers

Examples:
- `--priority high` – Modify priority
- `--dueDate tomorrow` – Set deadline
- `--recurring daily` – Repeating task
- `-v` – Verbose output

**Token** – Parsed input element

Types:
- Command token
- Argument token
- Option token
- Value token

#### B. Execution Entities

**CommandParser** – Input to structured command converter

Responsibilities:
- Tokenize input
- Validate syntax
- Extract intent
- Build ExecutionPlan

**ExecutionEngine** – Logic executor

Responsibilities:
- Route to correct handler
- Execute side effects
- Collect output
- Handle errors

**Context** – Runtime session state

Fields:
- `sessionVariables` – User-defined vars
- `workingDate` – Current day focus
- `workingProject` – Current project
- `userPreferences` – Loaded settings
- `recentCommands` – History buffer

**Result/Output** – Command response

Fields:
- `success` – Boolean outcome
- `data` – Returned content
- `message` – Human-readable status
- `errors` – Error details if failed
- `metadata` – Additional context

#### C. Session & Interaction

**Session** – User interaction lifecycle

Fields:
- `id` – Session identifier
- `startTime` – When session began
- `commands` – Commands executed
- `context` – Session variables
- `active` – Whether session live

**Prompt** – Input indicator

Formats:
- `> ` – ChronoSpark prompt
- `$ ` – System commands
- `↳ ` – Continuation

**History** – Previous command log

Supports:
- Search history
- Replay commands
- Clear history
- Export history

**InputStream/OutputStream** – Input/output handling

Features:
- Read user input
- Write output
- Handle errors
- Redirect output

#### D. Environment & State

**EnvironmentVariables** – Configuration values

Examples:
- `USER` – Current user
- `MODE` – production/dev/test
- `TIMEZONE` – User timezone
- `LANGUAGE` – UI language

**Configuration** – Console behavior settings

Options:
- `promptStyle` – Prompt format
- `outputFormat` – Table/JSON/text
- `colorEnabled` – Colored output
- `verbosity` – Log detail level

**WorkingDirectory** – Current context

Examples:
- Project scope
- Date scope
- Mission scope
- Tag scope

#### E. Advanced Console Features

**Script** – Batch command execution

Format:
```
create task "Task 1"
create task "Task 2"
schedule today
```

**Pipeline** – Command chaining

Format:
```
list incomplete | filter urgent | show count
```

**Job/Process** – Running async task

Examples:
- Long-running command
- Background task
- Scheduled automation

**Alias** – Command shortcut

Examples:
- `alias td = "task done"`
- `alias tl = "task list"`

**AutocompleteEngine** – Input suggestions

Features:
- Command completion
- Argument suggestions
- Option hints
- Recent command recall

**HelpSystem** – Documentation

Provides:
- Command reference
- Syntax examples
- Tutorial mode
- Context-sensitive help

#### F. AI/SI Extensions (Core Differentiator)

**NaturalLanguageCommand** – Conversational input

Examples:
- "plan my day" → `schedule today`
- "add workout tomorrow" → `task create "Workout" --dueDate tomorrow`
- "how am I doing?" → `log review --period week`

**CommandSuggestion** – Predictive action

Logic:
- Based on time of day
- Based on recent behavior
- Based on incomplete tasks
- Context-aware

**Intent** – Extracted meaning

Extracts:
- Action (create, update, delete, query)
- Entity (task, mission, log)
- Parameters (time, priority, etc.)
- Modifiers (urgent, recurring, etc.)

**AgentExecution** – Multi-step task automation

Examples:
- "catch me up" → list incomplete, show risks, suggest today's plan
- "optimize my day" → analyze logs, suggest focus times, adjust plan
- "review this week" → aggregate metrics, identify patterns, recommend changes

---

### SI Console Use Cases

#### A. Basic Command Execution

- **Execute command** – Parse and run
- **Parse command** – Extract structure
- **Validate arguments** – Check syntax
- **Return output** – Display result

#### B. CRUD Operations

- **Create** – Add task, mission, log, setting
- **Read** – List, view, search
- **Update** – Edit, modify, reschedule
- **Delete** – Remove, archive

#### C. Navigation & Context

- **Change focus date** – Switch day scope
- **Change project** – Switch project context
- **List all projects** – Show available scopes
- **Clear context** – Return to default

#### D. Session Interaction

- **Show prompt** – Accept input
- **Accept input** – Read user command
- **Display output** – Show result
- **Maintain state** – Preserve session

#### E. Command History

- **Save commands** – Store for replay
- **Search history** – Find past commands
- **Replay commands** – Re-execute
- **Export history** – Backup commands

#### F. Automation & Scripting

- **Run script** – Execute batch commands
- **Schedule commands** – Run at specific time
- **Chain commands** – Pipeline output
- **Create alias** – Shortcut custom command

#### G. Debugging & Monitoring

- **Show logs** – View recent events
- **Show errors** – Display failures
- **Inspect state** – View current system state
- **Check performance** – Monitor metrics

#### H. Context & State Management

- **Set variables** – Store user values
- **Read variables** – Retrieve stored values
- **Persist session** – Save state between sessions
- **Load workspace** – Restore previous state

#### I. Help & Discovery

- **Show help** – Command reference (`--help`)
- **List commands** – All available actions
- **Command examples** – Usage samples
- **Suggest commands** – Next probable actions

#### J. User Convenience Features

- **Autocomplete** – Tab completion
- **Suggest parameters** – Next argument hints
- **Validate syntax** – Warn before execute
- **Fuzzy match** – Forgive typos

#### K. AI/SI Special Use Cases

- **Natural language execution** – "add urgent task: fix bug"
- **Multi-step automation** – "plan my week and send summary"
- **Context-aware suggestions** – "what should I do now?"
- **Learning adaptation** – "show me what worked last week"
- **Error correction** – "did you mean: create task?"
- **Intelligent rescheduling** – "reschedule everything I missed"

---

### SI Console Command Structure

**Standard Format**:
```
command [subcommand] [arguments] [options]
```

**Examples**:
```
task create "Homework" --priority high --dueDate tomorrow
mission list --filter work --sort deadline
log review --period week --includeMetrics
schedule today --showFocusBlocks
setting change theme dark
```

**Natural Language Examples**:
```
add urgent task: fix login bug
plan my week based on my energy patterns
show me tasks I usually complete after 3pm
what's overdue and needs reschedule?
```

---

### SI Console API Reference

```
POST /console/execute          # Execute command
POST /console/parse            # Parse natural language
POST /console/suggestions      # Get command suggestions
POST /console/autocomplete     # Tab completion
GET /console/history           # Get command history
DELETE /console/history/:id    # Clear history entry
GET /console/help/:command     # Get command help
POST /console/script           # Execute batch commands
GET /console/context           # Get session state
POST /console/context          # Set session variables
```

---

### Entity Relationships

```
User → types → Input
Input → parsed by → CommandParser
Parser → extracts → Tokens
Tokens → matched to → Command
Command → routes to → ExecutionEngine
ExecutionEngine → uses → Context
Engine → produces → Result
Result → displayed in → Output
Output → stored in → History
History → accessible via → Session
```

---

### SI Console Integration with Ecosystem

The complete system interaction:

```
SI Console (Interface)
  ├─ commands to ChronoSpark (planning)
  ├─ queries ChronoLogs (insights)
  └─ modifies ChronoSettings (config)

ChronoSpark (Planning)
  ├─ executes SI Console commands
  ├─ logs actions for SI Console history
  └─ respects SI Console settings

ChronoLogs (Observability)
  ├─ records all SI Console commands
  ├─ provides data for SI Console queries
  └─ integrates with console search

ChronoSettings (Control)
  ├─ configures console behavior
  ├─ can be modified via SI Console
  └─ affects command execution
```

**Example Multi-System Flow**:
1. **User**: `"plan my day"`
2. **SI Console** parses → ChronoSpark generates plan
3. **ChronoSpark** executes → creates decision
4. **ChronoLogs** records → logs "plan generated"
5. **SI Console** displays → shows formatted plan
6. **ChronoSettings** applies → respects user preferences

---

### Unique SI Console Features

#### "Intelligent Command Suggestions"
Predicts next command based on:
- Time of day (morning → suggest plan review)
- Incomplete tasks (suggest completion)
- Overdue items (suggest rescheduling)
- User patterns (suggest frequent actions)

Example:
```
> task complete "Morning routine"
Done! [Suggestion] You usually work on Project X next. Add tasks for it?
```

#### "Natural Language Understanding"
Converts conversational input to commands:
- "I'm overwhelmed" → reduce suggestions, show recovery plan
- "I'm focused" → hide notifications, show deep work tasks
- "What should I do?" → generate top 3 recommendations

#### "Multi-Step Agent Execution"
Complex operations in one command:
```
"catch me up"
→ shows incomplete tasks
→ highlights overdue items
→ suggests quick wins
→ proposes today's schedule
```

#### "Learning from Corrections"
- User types wrong command
- Console suggests correction
- User accepts → system learns pattern
- Similar errors caught earlier next time

#### "Context Persistence"
- Set date: `focus 2026-06-25`
- All subsequent commands apply to that date
- Switch back: `focus today`
- Works across sessions

#### "Command Recording & Replay"
- `record "morning-routine"` – Start recording
- Execute commands...
- `stop` – End recording
- `replay "morning-routine"` – Run saved sequence
- Schedule: `schedule "morning-routine" daily at 8am`

#### "Natural Output Formatting"
Adapts output based on context:
- List mode: compact table
- Verbose mode: detailed breakdown
- JSON export: structured data
- Narrative mode: conversational summary

---

### SI Console Mental Model

```
┌─────────────────────────────────────────┐
│         User Natural Language           │
│    ("add task for tomorrow morning")    │
└─────────────────────────┬───────────────┘
                          │
                          ▼
┌─────────────────────────────────────────┐
│    Intent Recognition & Parsing         │
│  (extract: action, entity, parameters)  │
└─────────────────────────┬───────────────┘
                          │
                          ▼
┌─────────────────────────────────────────┐
│    Validation & Context Application     │
│  (verify syntax, apply session state)   │
└─────────────────────────┬───────────────┘
                          │
                          ▼
┌─────────────────────────────────────────┐
│    Route to Execution Handler           │
│  (dispatch to ChronoSpark/Logs/Settings)│
└─────────────────────────┬───────────────┘
                          │
                          ▼
┌─────────────────────────────────────────┐
│    Execute Action & Collect Result      │
│  (create, update, query, modify)        │
└─────────────────────────┬───────────────┘
                          │
                          ▼
┌─────────────────────────────────────────┐
│    Format & Display Output              │
│  (table, narrative, JSON, or visual)    │
└─────────────────────────┬───────────────┘
                          │
                          ▼
┌─────────────────────────────────────────┐
│    Log Command & Store in History       │
│  (for replay, audit, pattern learning)  │
└─────────────────────────────────────────┘
```

---

## System Integration & Architecture

### Complete System Overview

The four core systems work together in an integrated feedback loop:

```
          ┌──────────────────┐
          │   SI Console     │  ← User commands & NLP
          │   (Interface)    │  ← Execute & display
          └──────┬───────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    │            │            │
    ▼            ▼            ▼
┌─────────┐  ┌──────────┐  ┌─────────────┐
│ Settings│  │ChronoSpark│  │ ChronoLogs  │
│(Control)│  │ (Plan)   │  │  (Memory)   │
└─────────┘  └──────────┘  └─────────────┘
    │            │            │
    └────────────┼────────────┘
                 │
        [Feedback Loop]
        Logs → Patterns → 
        Settings Tune → Better Plans
```

---

### SI Console Entity Summary

**Core Execution** (6 entities):
- Command, Subcommand, Argument, Option/Flag, Token, CommandParser, ExecutionEngine, Output

**Session & Interaction** (4 entities):
- Session, Prompt, History, InputStream/OutputStream

**Context & Runtime** (4 entities):
- Context, EnvironmentVariables, WorkingDirectory, Configuration

**Advanced Console** (6 entities):
- Script, Pipeline, Job/Process, Alias, AutocompleteEngine, HelpSystem

**SI/AI Layer** (4 entities):
- NaturalLanguageCommand, Intent, CommandSuggestion, AgentExecution

**Core Use Cases** (11 workflows):
- Parse & execute, CRUD operations, session interaction, history & replay, automation, debugging, AI/SI execution

---

### Settings Entity Summary

**Core Model** (3 entities):
- SettingDefinition, SettingValue, SettingScope

**User Layer** (4 entities):
- UserPreferences, ProfileSettings, NotificationSettings, PrivacySettings

**Security Layer** (3 entities):
- SecuritySettings, PermissionSettings, AuthenticationSettings

**System Layer** (4 entities):
- FeatureFlag, AppSettings, EnvironmentSettings, PerformanceSettings

**Integration Layer** (2 entities):
- APISettings, IntegrationSettings

**Logging Integration** (2 entities):
- LoggingSettings, AuditSettings

**Enterprise Config** (3 entities):
- ConfigurationPolicy, SettingVersion, SettingAuditLog

**Core Use Cases** (11 workflows):
- CRUD, personalization, notifications, security, feature control, admin governance, logging, recovery

---

### ChronoLogs Entity Summary

**Core Log Model** (3 entities):
- LogEntry, Event, EventType/EventCategory

**Actors & Resources** (2 entities):
- Actor (user/system/AI), Resource (task/setting/etc.)

**Behavior Tracking** (3 entities):
- Session, ActivityStream, Interaction

**System Logs** (2 entities):
- LogType, SeverityLevel

**Analytics** (4 entities):
- Metrics, Pattern, Funnel, Insight

**Audit & Compliance** (3 entities):
- AuditLog, ChangeRecord, Trace

**Monitoring** (2 entities):
- Alert, Rule

**Storage** (2 entities):
- LogStream, RetentionPolicy

**Core Use Cases** (8 workflows):
- Core logging, tracking, audit, analytics, monitoring, security

---

## SI Console Complete Command Reference

### System Commands

```
help                    # Show command help
version                 # Show app version
exit / quit             # Exit console
clear                   # Clear screen
status                  # System status
health                  # System health check
ping                    # Test connection
about                   # About ChronoSpark
debug on/off            # Toggle debug mode
logs                    # Show recent logs
```

### Session Commands

```
session start           # Start new session
session stop            # End session
session list            # List active sessions
session reset           # Reset session state
session export          # Export session data
session import          # Import session data
```

### History Commands

```
history                 # Show command history
history search <query>  # Search history
history clear           # Clear history
history replay <n>      # Replay command N
history export          # Export history
```

### Context & Variables

```
set <var> <value>       # Set variable
get <var>               # Get variable value
unset <var>             # Remove variable
list vars               # List all variables
clear vars              # Clear all variables
```

### Task Commands (ChronoSpark)

```
task create "<name>"    # Create task
task list               # List tasks
task list incomplete    # List incomplete
task complete "<name>"  # Mark complete
task skip "<name>"      # Skip task
task delay "<name>" "<time>"  # Delay task
task update "<name>"    # Update task
task delete "<name>"    # Delete task
task prioritize "<name>" --priority high  # Set priority
task schedule "<name>" --time "3pm"  # Schedule
task assign "<name>" --project X     # Assign to project
```

### Project Commands

```
project create "<name>"  # Create project
project list             # List projects
project add-task "<task>" --project X  # Add task to project
project delete "<name>"  # Delete project
```

### Goals & Routines

```
goal create "<name>"     # Create goal
goal list                # List goals
goal track "<name>"      # Track progress
goal complete "<name>"   # Mark complete

routine create "<name>"  # Create routine
routine list             # List routines
routine run "<name>"     # Execute routine
routine edit "<name>"    # Edit routine
routine delete "<name>"  # Delete routine
```

### Time & Scheduling

```
schedule today           # Show today's schedule
schedule tomorrow        # Show tomorrow's schedule
schedule week            # Show week view
schedule auto            # Auto-schedule tasks
schedule optimize        # Optimize schedule

timeblock create --start 9am --end 11am # Create time block
timeblock list           # List time blocks
timeblock delete <id>    # Delete time block
```

### Logging & Analytics (ChronoLogs)

```
log show                 # Show recent logs
log filter --type task_created  # Filter logs
log search "<query>"     # Search logs
log export               # Export logs
log stats                # Show statistics

event list               # List events
event analyze            # Analyze patterns
```

### Audit & Compliance

```
audit show               # Show audit log
audit filter --by <user> # Filter audit
audit diff --setting X   # Show setting changes
audit rollback --version <n>  # Rollback to version

security status          # Security status
security check           # Security audit
security logs            # Show security logs
```

### Settings Commands

```
settings list            # List all settings
settings get <key>       # Get setting value
settings set <key> <value>  # Change setting
settings reset <key>     # Reset to default
settings export          # Export all settings
settings import          # Import settings

feature enable <name>    # Enable feature
feature disable <name>   # Disable feature
feature list             # List features

notify enable            # Enable notifications
notify disable           # Disable notifications
notify set-frequency daily  # Set frequency
```

### AI/SI Commands (Core Features)

```
plan day                 # Generate daily plan
plan week                # Generate weekly plan
plan goals               # Plan goal milestones

optimize schedule        # Optimize based on behavior
suggest tasks            # AI task suggestions
analyze productivity     # Productivity analysis

detect distractions      # Find distraction patterns
auto organize            # Auto-organize tasks
learn behavior           # Analyze patterns

what should i do?        # Get recommendation
catch me up              # Show incomplete + risks
review week              # Weekly review
```

### Natural Language Commands (Examples)

```
"plan my day"
"add urgent task: fix login bug"
"what did i do yesterday?"
"optimize my schedule for deep work"
"show my productivity patterns"
"i'm overwhelmed - help me prioritize"
"how much time did i spend on Project X?"
"reschedule everything i missed"
"what's my best focus time?"
"suggest a routine for mornings"
```

### Automation & Scripting

```
script create "<name>"   # Create command script
script run "<name>"      # Run saved script
script list              # List scripts
script delete "<name>"   # Delete script

cron add "<command>" "<schedule>"  # Add scheduled job
cron list                # List scheduled jobs
cron remove <id>         # Remove scheduled job
```

### System & Dev Commands

```
env list                 # List environment variables
env set <key> <value>    # Set environment variable
env unset <key>          # Unset variable

config show              # Show configuration
config reload            # Reload configuration

debug on                 # Enable debug mode
debug off                # Disable debug mode
```

### Pipeline & Advanced

```
run pipeline <name>      # Execute pipeline
pipeline create "<name>" # Create pipeline
pipeline list            # List pipelines
pipeline connect <from> <to>  # Chain commands
```

---

## Full Integrated Execution Flow

```
┌─────────────────────────────────────────┐
│    User Natural Language Input          │
│   ("plan my day based on energy")       │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│    SI Console Parser                    │
│  • Tokenize input                       │
│  • Extract intent & entities            │
│  • Match to commands                    │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│    Load Context                         │
│  • Current date & energy level          │
│  • User preferences (Settings)          │
│  • Recent behavior (ChronoLogs)         │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│    Route to Executor                    │
│  • ChronoSpark: plan generation         │
│  • ChronoLogs: query behavior           │
│  • Settings: apply preferences          │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│    Execute Operations                   │
│  • Generate optimal plan                │
│  • Filter/sort by energy patterns       │
│  • Apply user preferences               │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│    Log Actions (ChronoLogs)             │
│  • Record "command executed"            │
│  • Store input & output                 │
│  • Track user response                  │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│    Format & Display Output              │
│  • Structured table                     │
│  • Narrative summary                    │
│  • Interactive actions                  │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│    Generate Suggestions                 │
│  • Next logical command                 │
│  • Based on time/history                │
│  • Context-aware prompt                 │
└─────────────────────────────────────────┘
```

---

## Example End-to-End Flow

### Scenario: User requests daily optimization

**Input**:
```
> "optimize my schedule - i'm feeling low energy"
```

**SI Console Processing**:
1. Parse: Intent=optimize, Entity=schedule, Modifier=low_energy
2. Load context: energy=low, overdue_tasks=3, settings.suggestionAggressiveness=high
3. Route: ChronoSpark + ChronoLogs + Settings

**ChronoSpark Execution**:
1. Generate daily plan respecting low energy
2. Filter tasks: only urgent + quick-win items
3. Sort by energy requirement (easy first)
4. Apply user's timezone + work hours (Settings)

**ChronoLogs Recording**:
1. Log: `"console_command_executed: optimize_schedule"`
2. Store: input="optimize schedule", context="energy=low"
3. Track: user_response="accepted" or "modified"

**Output**:
```
✓ Optimized schedule created for today
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Time       Task                    Energy  Priority
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9:00-9:30  Quick email check       Low     Normal
9:30-10:00 Review urgent task      Low     High
10:00-11:00 Complete quick task    Low     High
[Rest suggested for recovery]

[Suggestion] You usually focus better after 2pm. 
Schedule heavy work then? Y/N
```

**Logs Generated**:
- Event: schedule_optimized
- Duration: 2.3s
- Changes: 5 tasks reordered
- User acceptance: pending

---

## Final System Model

**Three Core Principles**:

```
SI Console = EXECUTION INTERFACE
  ├─ Parses commands (structured + natural language)
  ├─ Routes to ChronoSpark, ChronoLogs, Settings
  └─ Displays results + generates suggestions

Settings = CONTROL & CONFIGURATION
  ├─ Defines behavior (no code changes needed)
  ├─ Personalizes experience per user
  └─ Layers override: user > app > system

ChronoLogs = MEMORY & ANALYTICS
  ├─ Records every action with timestamp
  ├─ Analyzes patterns & behavior
  └─ Feeds insights back to suggestions
```

**Feedback Loop**:
```
User Action
    ↓
SI Console executes
    ↓
ChronoSpark plans / changes made
ChronoLogs records changes
Settings applied
    ↓
Logs analyzed → Patterns extracted
    ↓
Patterns inform SI Engine
    ↓
Next command suggestions become smarter
```

**Data Flow**:
```
Intent → Command → Context + Settings → Action
              ↓
           Logged
              ↓
        Analyzed → Insight
              ↓
        Suggestions improve
```

**Completeness**:
- **Planning**: ChronoSpark handles creation, scheduling, recommendations
- **Observability**: ChronoLogs captures everything with audit trail
- **Control**: Settings personalizes all behavior
- **Interface**: SI Console provides command + NLP access to all systems
- **Learning**: Patterns from logs → smarter suggestions → better plans

---

## Subscription System (Production Monetization)

### Overview

ChronoSpark implements a **subscription-only, no-ads, premium-focused monetization model** with three tiers: **Base (Free)**, **Premium**, and **Ultimate**. The system uses mock billing for development and integrates cleanly with existing architecture.

### Tiers & Pricing

**BASE (Free) ✦**
- Price: $0/month
- Temporal Ops: 5 trial opens
- SI Console: 8 trial opens
- SI Engine: Limited to 2 focus tasks
- History: Last 7 days
- Adaptive Learning: Basic mode
- Decision Refresh: 60 minutes

**PREMIUM ★**
- Price: $7.99/month | $59.99/year (saves $35.88/year)
- Unlimited Temporal Ops & SI Console
- SI Engine: 5 focus tasks
- History: 30 days
- Full adaptive learning
- Decision Refresh: 30 minutes

**ULTIMATE ✦✦✦**
- Price: $12.99/month | $99.99/year (saves $56.88/year)
- All Premium features PLUS:
- Unlimited history (365 days)
- Advanced analytics & trends
- SI Engine: 7 focus tasks, enhanced output
- Deep SI insights & predictions
- Custom themes & advanced tagging
- Decision Refresh: 15 minutes
- Early access to new features

### How It Works

1. **Base users** get trial quotas (5 + 8 opens)
2. When trials exhaust → `PremiumFeatureGate` prompts upgrade
3. **Upgrade flow** is non-intrusive, available in Settings
4. **Premium+ users** bypass all quotas and get full feature access
5. **Downgrade** at any time, keeps all data intact
6. **Refund eligible** for 14 days after signup (mocked)

### Technical Implementation

**Subscription Fields in AppState**:
```dart
late SubscriptionSnapshot _subscription;
SubscriptionPlan get currentPlan => _subscription.plan;
bool get isPremium => _subscription.plan.isPremium;
bool get isUltimate => _subscription.plan.isUltimate;
```

**Trial Quota Logic (Updated)**:
```dart
Future<bool> consumeTemporalOpsTrialIfNeeded() async {
  // Premium+ users have unlimited access
  if (isPremium) return true;
  
  // Base tier uses trial system
  if (temporalTrialRemaining <= 0) return false;
  
  _temporalTrialUses += 1;
  await _autoSave();
  return true;
}
```

**SI Engine Scaling**:
- Base: 2 focus tasks, no optional action
- Premium: 5 focus tasks, full output
- Ultimate: 7 focus tasks, enhanced reasoning

**Adaptive Learning Scaling**:
- Base: 7-day retention, 0.6x learning depth
- Premium: 30-day retention, 1.0x learning depth
- Ultimate: 365-day retention, 1.4x learning depth + analytics

**Persistence**:
```json
{
  "subscription": {
    "plan": "premium",
    "billingCycle": "monthly",
    "status": "active",
    "subscriptionStartDate": "2026-06-21T...",
    "mockNextBillingDate": "2026-07-21T..."
  }
}
```

### UI Component

**SubscriptionBillingWidget** in Settings:
- Current plan badge with refund eligibility
- Billing cycle toggle (monthly/yearly with savings badge)
- Pricing tier cards with features list
- Subscription details (dates, status)
- Promo code application
- Downgrade confirmation with warning

### Principles

✅ **NO ADS** - Clean, premium experience
✅ **NO POPUPS** - Graceful upgrade prompts only
✅ **SUBSCRIPTION-ONLY** - No in-app purchases
✅ **TRIAL-FIRST** - Test before upgrade
✅ **DATA PRESERVED** - Downgrade keeps everything
✅ **BACKWARD COMPATIBLE** - Old snapshots auto-default to Base

### Replace with Real Provider

When ready, swap `MockBillingService` with real provider:
- RevenueCat (recommended - handles iOS/Android/Web)
- Stripe Billing
- PaddleCRM
- Custom backend

The abstraction ensures minimal code changes.

---

## Future Roadmap

- Migrate persistence to Hive/SQLite for richer queries and scalability
- Implement SI Console natural language understanding with entity extraction
- Add multi-step agent execution for complex workflows
- Build command recording & replay with scheduling
- Implement intelligent command suggestions with behavior learning
- Add "command autopilot" mode for hands-off execution
- Create settings profiles (Productivity/Relaxed/DeepWork modes)
- Build settings sync across devices (cloud-backed)
- Integrate external calendar providers (Google Calendar, Outlook)
- Build mobile companion app with voice input to SI Console
- Implement habit-tracking and long-term goal forecasting

---

## License & Credits

ChronoSpark is a personal productivity project built with Flutter and Dart. All assets and code are original or properly licensed.


---

## GitHub Repository Essentials

This repository also includes baseline GitHub safeguards and hygiene files:

- Secret scanning workflow: `.github/workflows/secret-scan.yml` (gitleaks)
- Flutter/Dart-focused `.gitignore`
- MIT `LICENSE`

The secret scan runs on pull requests and pushes to `main` to detect leaked API keys/tokens.
