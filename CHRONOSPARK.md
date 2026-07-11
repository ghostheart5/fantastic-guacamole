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

## Setup Alignment

This canonical alignment maps product scope to staged delivery tiers and core feature use-case folders.

### MVP Core

- Authentication
- User Profile
- Dashboard
- Goals
- Tasks
- Habits
- Habit Streaks
- Daily Plan
- Smart Coach Basic
- SI Console Basic
- Offline Handling
- Error Handling
- Settings
- Privacy/Delete Account

### MVP Plus

- Projects
- Timeline
- Analytics
- Notifications
- Memory System
- Weekly Planning
- Goal Forecasting
- Habit Recommendations
- Smart Coach Advanced
- SI Console Advanced

### Elite Version

- Future Self System
- Identity Alignment
- Life Balance Analysis
- Advanced Forecasting
- Momentum Engine
- Gamification
- Premium Paywall
- AI Context Memory
- Cross-System Recommendations
- Personal Operating System Analysis

### Core Feature Use-Case Folders

- auth
- profile
- onboarding
- dashboard
- goals
- tasks
- projects
- habits
- streaks
- planner
- timeline
- smart_coach
- si_console
- memory
- journal
- analytics
- notifications
- gamification
- settings
- sync
- offline
- errors
- ai_engine
- subscription
- legal
- qa

---

## Architecture

### Technology Stack

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod providers (with legacy compatibility where needed)
- **Persistence**: `SharedPreferences` via abstracted `RuntimePersistence` layer (designed for future Hive/SQLite upgrades)
- **Typography**: Google Fonts (Orbitron, Inter, etc.)
- **UI Pattern**: Material 3 + custom glassmorphic components

Layer dependency direction contract: `UI (features) -> Riverpod providers (state) -> Repositories (data/di) -> Services (Supabase/storage) -> Engine (logic layer)`.
See `docs/LAYER_FLOW.md`.

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

## ChronoSpark Master Entity List

### 1. Auth / Account Entities

- **UserAccount**
- **AuthSession**
- **AuthProvider**
- **LoginCredential**
- **PasswordResetRequest**
- **EmailVerification**
- **AccountDeletionRequest**
- **UserConsent**
- **PrivacySetting**
- **UserDataExport**

### 2. User Profile Entities

- **UserProfile**
- **UserPreference**
- **UserSettings**
- **UserAvatar**
- **UserTimezone**
- **UserThemePreference**
- **UserNotificationPreference**
- **UserCoachingPreference**
- **UserLifeAreaPreference**
- **UserOnboardingState**

### 3. Onboarding Entities

- **OnboardingFlow**
- **OnboardingStep**
- **OnboardingAnswer**
- **OnboardingGoalSelection**
- **OnboardingHabitSelection**
- **OnboardingFocusArea**
- **StarterPlan**
- **IntroCard**
- **SetupProgress**

### 4. Goal Entities

- **Goal**
- **GoalCategory**
- **GoalStatus**
- **GoalPriority**
- **GoalMilestone**
- **GoalProgress**
- **GoalMetric**
- **GoalTarget**
- **GoalDeadline**
- **GoalMotivation**
- **GoalReflection**
- **GoalRisk**
- **GoalRecommendation**
- **GoalHealthScore**
- **GoalForecast**

### Example Goal Fields

- id
- userId
- title
- description
- category
- status
- priority
- startDate
- targetDate
- progressPercent
- createdAt
- updatedAt

### 5. Milestone Entities

- **Milestone**
- **MilestoneStatus**
- **MilestoneProgress**
- **MilestoneDeadline**
- **MilestoneReward**
- **MilestoneReminder**
- **MilestoneReflection**

### 6. Task Entities

- **Task**
- **TaskStatus**
- **TaskPriority**
- **TaskCategory**
- **TaskSchedule**
- **TaskReminder**
- **TaskRecurrence**
- **TaskDependency**
- **TaskNote**
- **TaskCompletion**
- **TaskEnergyLevel**
- **TaskDifficulty**
- **TaskDurationEstimate**
- **TaskTag**
- **TaskAttachment**
- **TaskRecommendation**

### Example Task Fields

- id
- userId
- goalId
- projectId
- title
- description
- status
- priority
- dueDate
- completedAt
- createdAt
- updatedAt

### 7. Project Entities

- **Project**
- **ProjectStatus**
- **ProjectCategory**
- **ProjectPriority**
- **ProjectGoalLink**
- **ProjectTaskLink**
- **ProjectMilestone**
- **ProjectTimeline**
- **ProjectProgress**
- **ProjectRisk**
- **ProjectHealthScore**
- **ProjectRecommendation**
- **ProjectForecast**

### 8. Habit Entities

- **Habit**
- **HabitCategory**
- **HabitStatus**
- **HabitFrequency**
- **HabitSchedule**
- **HabitReminder**
- **HabitCompletion**
- **HabitLog**
- **HabitNote**
- **HabitMood**
- **HabitEffort**
- **HabitQuantity**
- **HabitProgress**
- **HabitHealthScore**
- **HabitRecommendation**
- **HabitForecast**

### Example Habit Fields

- id
- userId
- title
- description
- category
- frequency
- targetCount
- status
- createdAt
- updatedAt

### 9. Habit Streak Entities

- **HabitStreak**
- **StreakStatus**
- **StreakMilestone**
- **StreakReward**
- **StreakBreak**
- **StreakRecoveryPlan**
- **StreakHistory**
- **StreakForecast**
- **StreakRisk**
- **StreakBadge**

### Example Streak Fields

- id
- habitId
- userId
- currentCount
- longestCount
- startedAt
- lastCompletedAt
- brokenAt
- status

### 10. Daily Planning Entities

- **DailyPlan**
- **DailyPlanItem**
- **DailyPriority**
- **DailyFocus**
- **DailyReflection**
- **DailySummary**
- **DailyScore**
- **DailyReview**
- **FocusBlock**
- **RoutineBlock**
- **BreakBlock**

### 11. Weekly Planning Entities

- **WeeklyPlan**
- **WeeklyGoal**
- **WeeklyPriority**
- **WeeklyTaskSummary**
- **WeeklyHabitSummary**
- **WeeklyReflection**
- **WeeklyReview**
- **WeeklyScore**
- **WeeklyCarryOver**

### 12. Timeline Entities

- **TimelineEvent**
- **TimelineItem**
- **TimelineMilestone**
- **TimelineDeadline**
- **TimelineRange**
- **TimelineConflict**
- **TimelineRisk**
- **TimelineForecast**
- **TimelineSnapshot**
- **TimelineReview**

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

### 🧠 H. Authentication & Account Use Cases

User identity and account lifecycle operations:

- **Sign up** – Create a new user account
- **Log in** – Authenticate with account credentials
- **Log out** – End the current authenticated session
- **Reset password** – Request and complete password reset flow
- **Verify email** – Confirm account email ownership
- **Update email** – Change account email address
- **Update password** – Change account password
- **Delete account** – Permanently remove the user account
- **Export user data** – Download account and usage data
- **Manage privacy settings** – Configure consent and data-sharing preferences
- **Manage notification permissions** – Configure push/email/in-app notification access
- **Manage account settings** – Update profile and account-level preferences
- **Handle auth failure** – Show mapped errors and recovery actions
- **Handle offline login state** – Graceful behavior when connectivity is unavailable
- **Restore user session** – Rehydrate valid session on app restart

### 🧠 I. User Profile Use Cases

Profile creation, personalization, and identity context operations:

- **Create user profile** – Initialize a profile for a new user
- **Edit user profile** – Update profile fields and personal details
- **View user profile** – Display current profile information
- **Set display name** – Configure the user-facing name
- **Set avatar** – Configure profile image
- **Set timezone** – Configure scheduling and display timezone
- **Set preferences** – Configure core personalization settings
- **Set primary life goals** – Store high-level long-term user goals
- **Set coaching style** – Configure assistant tone and guidance style
- **Set theme preference** – Configure visual theme behavior
- **Set notification preference** – Configure notification behavior
- **Set onboarding progress** – Persist onboarding completion state
- **Update personal context** – Refresh user context used for recommendations
- **View user summary** – Display consolidated identity and preference summary

### 🧠 J. Onboarding Use Cases

First-run setup and guided activation flows:

- **Start onboarding** – Begin first-time user setup flow
- **Complete onboarding** – Finish onboarding and unlock full app flow
- **Skip onboarding** – Bypass setup and enter app with defaults
- **Choose main goals** – Select primary long-term objectives
- **Choose focus areas** – Select key domains to prioritize
- **Choose habit goals** – Select habit-building targets
- **Choose productivity style** – Select planning and execution style
- **Choose coaching tone** – Select assistant personality and tone
- **Choose reminder preferences** – Configure notification cadence and channels
- **Create first goal** – Create the user's first goal during onboarding
- **Create first task** – Create the user's first actionable task
- **Create first habit** – Create the user's first recurring habit
- **Generate starter plan** – Build an initial plan from onboarding inputs
- **Show app tour** – Present guided walkthrough of core surfaces
- **Show coach introduction** – Introduce coaching behavior and expectations
- **Show SI console introduction** – Introduce SI Console capabilities and usage

### 🧠 K. Dashboard Use Cases

Home surface visibility, insight consumption, and layout controls:

- **View dashboard** – Open and view the main dashboard surface
- **View daily summary** – See today's completion and activity highlights
- **View weekly summary** – See weekly performance and trend highlights
- **View goal snapshot** – See condensed goal progress status
- **View task snapshot** – See condensed task status and priorities
- **View habit snapshot** – See condensed habit streak and completion state
- **View timeline snapshot** – See short-form upcoming and recent timeline items
- **View momentum score** – See current execution and consistency momentum score
- **View priority card** – See top-priority recommended work item
- **View coach suggestions** – See coaching recommendations for next actions
- **View SI insights** – See SI-generated patterns and strategic guidance
- **Refresh dashboard** – Reload dashboard data and recompute insight cards
- **Customize dashboard widgets** – Configure visible widget set and behavior
- **Hide dashboard widget** – Remove a widget from active layout
- **Reorder dashboard widgets** – Change widget ordering in the layout

### 🧠 K2. Dashboard Analytics Use Cases

Dashboard analytics visibility, reporting, and trend-inspection operations:

- **View progress analytics** – View aggregate progress performance metrics
- **View goal analytics** – View goal-specific analytics and trends
- **View task analytics** – View task execution analytics and distribution
- **View habit analytics** – View habit adherence analytics and trends
- **View streak analytics** – View streak performance and streak trend analytics
- **View project analytics** – View project-level delivery analytics
- **View productivity analytics** – View productivity output and efficiency analytics
- **View momentum analytics** – View momentum trend and acceleration analytics
- **View completion analytics** – View completion-rate and throughput analytics
- **View consistency analytics** – View execution consistency analytics over time
- **View timeline analytics** – View time-allocation and schedule analytics
- **View weekly report** – View synthesized weekly analytics report
- **View monthly report** – View synthesized monthly analytics report

### 🧠 K3. Advanced Analytics Use Cases

Cross-domain scoring, rate computation, and pattern-detection operations:

- **Calculate momentum score** – Compute momentum score from progress velocity and consistency
- **Calculate productivity score** – Compute productivity score from output and efficiency signals
- **Calculate goal health score** – Compute goal health score from status, pace, and risk factors
- **Calculate habit health score** – Compute habit health score from adherence and trend stability
- **Calculate life balance score** – Compute life balance score across key life domains
- **Calculate consistency score** – Compute consistency score from behavioral regularity over time
- **Calculate completion rate** – Compute completion ratio across selected entities/time windows
- **Calculate overdue rate** – Compute overdue ratio across active commitments
- **Calculate focus score** – Compute focus quality score from deep-work and interruption signals
- **Calculate risk score** – Compute aggregate risk score from detected risk indicators
- **Detect progress patterns** – Detect recurring progress and acceleration patterns
- **Detect failure patterns** – Detect recurring failure and drop-off patterns
- **Detect success patterns** – Detect recurring success and high-performance patterns

### 🧠 K4. Momentum System Use Cases

Momentum scoring, trend tracking, and momentum-recovery guidance operations:

- **Calculate daily momentum** – Compute momentum score for the current day
- **Calculate weekly momentum** – Compute momentum score for the current week
- **Calculate goal momentum** – Compute momentum signal for active goals
- **Calculate habit momentum** – Compute momentum signal from habit adherence
- **Calculate task momentum** – Compute momentum signal from task throughput
- **Increase momentum score** – Raise momentum score from positive execution events
- **Decrease momentum score** – Lower momentum score from negative drift events
- **Recover momentum** – Apply recovery logic to restore momentum trajectory
- **Show momentum trend** – Display momentum trend over selected time windows
- **Show momentum insight** – Display interpretation of current momentum state
- **Recommend momentum action** – Recommend best next action to improve momentum

### 🧠 K5. Theme Use Cases

Visual theme selection and interface personalization operations:

- **Change theme** – Switch active application theme
- **Use light theme** – Apply light visual theme
- **Use dark theme** – Apply dark visual theme
- **Use prism theme** – Apply prism visual theme
- **Use futuristic theme** – Apply futuristic visual theme
- **Use shadowfire theme** – Apply shadowfire visual theme
- **Customize accent color** – Set theme accent color
- **Customize dashboard layout** – Adjust dashboard visual arrangement
- **Customize widget visibility** – Show/hide dashboard widgets
- **Customize text size** – Adjust global text size for readability
- **Customize app icon** – Select alternate app icon style

### 🧠 K6. App Settings Use Cases

Application configuration and user preference management operations:

- **Update app settings** – Update global application settings
- **Update notification settings** – Configure notification preferences and delivery behavior
- **Update privacy settings** – Configure privacy and data-sharing preferences
- **Update coach settings** – Configure coaching behavior and personalization options
- **Update SI console settings** – Configure SI Console behavior and preferences
- **Update data settings** – Configure data sync, backup, and retention options
- **Update accessibility settings** – Configure accessibility and assistive features
- **Update language settings** – Configure application language/localization
- **Update time format** – Configure 12-hour or 24-hour time display
- **Update date format** – Configure regional date display format
- **Reset settings** – Reset configurable settings to defaults

### 🧠 K7. Local Data Use Cases

Local persistence, caching, and offline data-access operations:

- **Save local data** – Persist data to local storage
- **Read local data** – Read data from local storage
- **Update local data** – Update existing local data records
- **Delete local data** – Remove local data records
- **Cache dashboard data** – Cache dashboard payloads for fast loading
- **Cache user profile** – Cache user profile for offline access
- **Cache goals** – Cache goal records locally
- **Cache tasks** – Cache task records locally
- **Cache habits** – Cache habit records locally
- **Cache projects** – Cache project records locally
- **Cache timeline** – Cache timeline records/events locally

### 🧠 K8. Sync Use Cases

Cloud synchronization, offline queueing, and conflict-resolution operations:

- **Sync user data** – Synchronize user profile and account data
- **Sync goals** – Synchronize goal records
- **Sync tasks** – Synchronize task records
- **Sync habits** – Synchronize habit records
- **Sync projects** – Synchronize project records
- **Sync timeline** – Synchronize timeline records/events
- **Sync memories** – Synchronize memory records
- **Sync analytics** – Synchronize analytics snapshots and metrics
- **Resolve sync conflict** – Resolve local/cloud data conflicts
- **Retry failed sync** – Retry failed synchronization operations
- **Queue offline change** – Queue local changes while offline
- **Process offline queue** – Process queued changes when connectivity returns
- **Restore from cloud** – Restore local state from cloud snapshot

### 🧠 K9. Offline Mode Use Cases

Offline operation handling, user feedback, and reconnection recovery operations:

- **Enter offline mode** – Transition app into offline-capable state
- **Exit offline mode** – Transition app back to online-capable state
- **Detect offline state** – Detect network loss and offline conditions
- **Show offline banner** – Display persistent offline status indicator
- **Allow offline task updates** – Allow task modifications while offline
- **Allow offline habit updates** – Allow habit modifications while offline
- **Allow offline goal updates** – Allow goal modifications while offline
- **Save offline changes** – Persist offline mutations for later sync
- **Sync when online** – Trigger synchronization when connectivity returns
- **Handle sync failure** – Handle synchronization failures gracefully
- **Handle limited mode** – Restrict unsupported features in offline/limited mode

### 🧠 K10. Error Handling Use Cases

Runtime fault handling, user-safe degradation, and reliability operations:

- **Handle auth backend unavailable** – Handle unavailable authentication backend
- **Handle database unavailable** – Handle unavailable database dependencies
- **Handle network error** – Handle connectivity and transport failures
- **Handle timeout error** – Handle operation timeout conditions
- **Handle permission error** – Handle denied authorization/permission states
- **Handle validation error** – Handle invalid data and rule-validation failures
- **Handle empty state** – Handle no-data states with safe fallback UI
- **Handle missing data** – Handle incomplete or absent required data
- **Handle sync error** – Handle synchronization processing failures
- **Handle AI response error** – Handle failed or invalid AI response payloads
- **Handle invalid user input** – Handle malformed or unsupported user input
- **Retry failed action** – Retry failed operations with recovery logic
- **Show friendly error message** – Show user-readable and actionable error feedback
- **Log error** – Record error details for diagnostics
- **Report crash** – Send crash reports for incident analysis

### 🧠 K11. State Recovery Use Cases

Session continuity, draft restoration, and interrupted-flow recovery operations:

- **Recover last session** – Restore previous app session state
- **Restore unsaved draft** – Restore unsaved input/content drafts
- **Restore last screen** – Return user to last active screen
- **Restore failed task update** – Recover failed task mutation attempt
- **Restore failed habit update** – Recover failed habit mutation attempt
- **Restore failed goal update** – Recover failed goal mutation attempt
- **Resume onboarding** – Resume interrupted onboarding flow
- **Resume daily plan** – Resume interrupted daily planning flow
- **Resume coach conversation** – Resume interrupted coaching conversation state
- **Resume SI query** – Resume interrupted SI Console query flow

### 🧠 K12. Free Plan Use Cases

Free-tier access, limits visibility, and usage tracking operations:

- **Use free features** – Access features available in free tier
- **View free limits** – View free-tier usage caps and restrictions
- **Hit free limit** – Handle limit-reached state for free-tier usage
- **Show upgrade prompt** – Show premium upgrade prompt at limit boundaries
- **Track free usage** – Track free-tier feature usage consumption
- **Reset monthly free usage** – Reset monthly free-tier quotas

### 🧠 K13. Premium Plan Use Cases

Subscription lifecycle, entitlement validation, and premium unlock operations:

- **View premium features** – View premium feature catalog and benefits
- **Start subscription** – Start premium subscription purchase flow
- **Restore purchase** – Restore prior premium purchase/subscription
- **Cancel subscription** – Cancel active premium subscription
- **Check entitlement** – Validate premium entitlement status
- **Unlock premium coach** – Unlock premium coaching capabilities
- **Unlock SI console** – Unlock SI Console premium capabilities
- **Unlock advanced analytics** – Unlock advanced analytics capabilities
- **Unlock forecasting** – Unlock forecasting capabilities
- **Unlock custom themes** – Unlock premium custom theme library
- **Unlock unlimited goals** – Unlock unlimited goal capacity
- **Unlock unlimited habits** – Unlock unlimited habit capacity

### 🧠 K14. Internal Testing Use Cases

Internal diagnostics, subsystem verification, and environment validation operations:

- **Run app health check** – Run overall application health diagnostics
- **Run auth test** – Run authentication flow and auth-service tests
- **Run database test** – Run database connectivity and CRUD integrity tests
- **Run offline test** – Run offline-mode behavior and persistence tests
- **Run sync test** – Run sync pipeline and conflict-resolution tests
- **Run notification test** – Run notification delivery and scheduling tests
- **Run coach test** – Run Smart Coach interaction and response tests
- **Run SI console test** – Run SI Console command and response tests
- **Run analytics test** – Run analytics computation and reporting tests
- **Run crash reporting test** – Run crash capture and reporting pipeline test
- **Validate environment variables** – Validate required runtime environment variables
- **Validate Supabase config** – Validate Supabase configuration and connectivity
- **Validate Firebase config** – Validate Firebase configuration and connectivity
- **Validate routing** – Validate navigation and route-guard behavior
- **Validate permissions** – Validate runtime and feature permission behavior

### 🧠 L. Goal Management Use Cases

Goal lifecycle, visibility, and organization operations:

- **Create goal** – Add a new goal
- **Edit goal** – Modify goal details
- **Delete goal** – Permanently remove a goal
- **Archive goal** – Move a goal out of active view
- **Restore goal** – Bring an archived goal back to active state
- **Complete goal** – Mark goal as completed
- **Pause goal** – Temporarily suspend progress tracking
- **Resume goal** – Reactivate a paused goal
- **View goal** – Open goal details
- **View all goals** – List every goal state
- **View active goals** – List goals currently in progress
- **View completed goals** – List goals marked done
- **View archived goals** – List goals moved to archive
- **Search goals** – Find goals by query
- **Filter goals** – Narrow goal list by criteria
- **Sort goals** – Reorder goals by selected sort mode
- **Pin goal** – Prioritize a goal at top of list
- **Unpin goal** – Remove pinned priority from a goal

### 🧠 M. Goal Planning Use Cases

Goal definition, decomposition, and plan design operations:

- **Break goal into milestones** – Decompose a goal into phased checkpoints
- **Break goal into tasks** – Decompose a goal into executable tasks
- **Set goal deadline** – Define final due date for the goal
- **Set goal priority** – Define urgency/importance level
- **Set goal category** – Classify goal under a domain/category
- **Set goal motivation** – Capture why the goal matters
- **Set goal success criteria** – Define completion conditions
- **Set goal measurement type** – Define how progress is measured
- **Set goal target value** – Define the numeric or qualitative target
- **Set goal start date** – Define when execution begins
- **Set goal end date** – Define planned completion date
- **Create goal roadmap** – Build milestone and timeline sequence
- **Generate goal plan** – Auto-create a structured plan from inputs
- **Adjust goal plan** – Modify roadmap/tasks as context changes

### 🧠 N. Goal Progress Use Cases

Goal tracking, analysis, and predictive guidance operations:

- **Update goal progress** – Record current progress state
- **Track goal completion percentage** – Measure percent complete
- **Track goal milestones** – Monitor milestone completion status
- **Track goal tasks** – Monitor linked task execution status
- **Track goal habits** – Monitor contributing habit consistency
- **Calculate goal health** – Compute overall goal quality/viability score
- **Calculate goal momentum** – Compute pace and consistency trend
- **Analyze goal progress** – Evaluate patterns and blockers
- **Forecast goal completion** – Predict likely completion timeline
- **Detect goal risk** – Identify risk of non-completion
- **Detect goal delay** – Identify schedule slippage
- **Detect goal conflict** – Identify conflicts with other goals/plans
- **Recommend goal next action** – Suggest highest-impact next step

### 🧠 O. Goal Intelligence & Strategy Use Cases

Advanced multi-goal analysis, prioritization, and recovery operations:

- **Analyze active goals** – Evaluate current in-progress goals as a portfolio
- **Find highest priority goal** – Identify the top-priority goal now
- **Find neglected goals** – Identify goals with insufficient recent progress
- **Find overloaded goals** – Identify goals with unrealistic scope or load
- **Find conflicting goals** – Identify goals competing for time/resources
- **Find most impactful goal** – Identify goal with highest expected outcome value
- **Find goal bottlenecks** – Identify blocked dependencies and constraints
- **Generate goal recommendations** – Produce strategic optimization suggestions
- **Generate goal recovery plan** – Build recovery path for at-risk goals
- **Generate goal forecast** – Produce projection across multiple scenarios
- **Analyze goal alignment** – Evaluate alignment with values and priorities
- **Analyze future self alignment** – Evaluate alignment with desired future identity
- **Analyze life area balance** – Evaluate distribution across life domains

### 🧠 P. Tasks System Use Cases

Task lifecycle, retrieval, and list-organization operations:

- **Create task** – Add a new task
- **Edit task** – Modify task details
- **Delete task** – Permanently remove a task
- **Archive task** – Move task out of active views
- **Restore task** – Bring archived task back to active state
- **Complete task** – Mark task as done
- **Uncomplete task** – Reopen a completed task
- **View task** – Open task details
- **View all tasks** – List tasks across all states
- **View open tasks** – List actionable/incomplete tasks
- **View completed tasks** – List completed tasks
- **View archived tasks** – List archived tasks
- **Search tasks** – Find tasks by query
- **Filter tasks** – Narrow task list by criteria
- **Sort tasks** – Reorder tasks by selected sort mode
- **Pin task** – Prioritize task at top of list
- **Unpin task** – Remove pinned priority from task

### 🧠 Q. Task Scheduling & Configuration Use Cases

Task timing, effort, and execution-planning operations:

- **Set task due date** – Assign a final due date
- **Set task start date** – Assign earliest start date
- **Set task reminder** – Configure reminder notifications
- **Set task priority** – Assign urgency/importance level
- **Set task category** – Classify task by domain/category
- **Set task duration** – Define expected effort duration
- **Set task energy level** – Define required energy intensity
- **Set task difficulty** – Define estimated complexity level
- **Set task recurrence** – Configure repeating schedule
- **Schedule task** – Place task into a specific time slot/plan
- **Reschedule task** – Move task to a different time/date
- **Snooze task** – Delay task reminder/execution temporarily
- **Move task to tomorrow** – Shift task to next-day plan
- **Move task to this week** – Shift task into weekly plan horizon

### 🧠 R. Task Intelligence Use Cases

Task discovery, prioritization intelligence, and predictive operations:

- **Find tasks due today** – Surface tasks with due date today
- **Find tasks due tomorrow** – Surface tasks with due date tomorrow
- **Find tasks due this week** – Surface tasks due within the current week
- **Find overdue tasks** – Surface tasks past due date
- **Find high priority tasks** – Surface urgent/important tasks first
- **Find low energy tasks** – Surface tasks suitable for low energy states
- **Find quick win tasks** – Surface short, high-completion-probability tasks
- **Find deep work tasks** – Surface focus-intensive tasks requiring long blocks
- **Find blocked tasks** – Surface tasks blocked by dependencies or constraints
- **Find neglected tasks** – Surface stale tasks with no recent progress
- **Recommend next task** – Suggest best next task given context
- **Analyze task load** – Evaluate workload volume and distribution
- **Analyze task completion rate** – Measure completion throughput over time
- **Analyze task patterns** – Detect behavioral and execution trends
- **Forecast task completion** – Predict likely completion timelines

### 🧠 S. Project Management Use Cases

Project lifecycle, retrieval, and organization operations:

- **Create project** – Add a new project
- **Edit project** – Modify project details
- **Delete project** – Permanently remove a project
- **Archive project** – Move project out of active views
- **Restore project** – Bring archived project back to active state
- **Complete project** – Mark project as completed
- **Pause project** – Temporarily suspend project execution
- **Resume project** – Reactivate a paused project
- **View project** – Open project details
- **View all projects** – List projects across all states
- **View active projects** – List projects currently in progress
- **View completed projects** – List projects marked done
- **Search projects** – Find projects by query
- **Filter projects** – Narrow project list by criteria
- **Sort projects** – Reorder projects by selected sort mode

### 🧠 T. Project Planning Use Cases

Project roadmap design, progress monitoring, and strategic planning operations:

- **Create project roadmap** – Build phased timeline and delivery plan
- **Set project deadline** – Define final due date for the project
- **Set project priority** – Define urgency/importance level
- **Set project category** – Classify project by domain/category
- **Add project goals** – Link supporting goals to the project
- **Add project tasks** – Add executable tasks under the project
- **Add project milestones** – Add key checkpoints and phase gates
- **Add project notes** – Capture planning context and decisions
- **Track project progress** – Monitor completion and execution status
- **Calculate project health** – Compute project viability/health score
- **Detect project risks** – Identify delivery and scope risks
- **Generate project recommendations** – Produce optimization suggestions
- **Forecast project completion** – Predict likely completion timeline

### 🧠 U. Habit Management Use Cases

Habit lifecycle, retrieval, and organization operations:

- **Create habit** – Add a new habit
- **Edit habit** – Modify habit details
- **Delete habit** – Permanently remove a habit
- **Archive habit** – Move habit out of active views
- **Restore habit** – Bring archived habit back to active state
- **Pause habit** – Temporarily suspend habit tracking
- **Resume habit** – Reactivate a paused habit
- **View habit** – Open habit details
- **View all habits** – List habits across all states
- **View active habits** – List habits currently in progress
- **View completed habits** – List habits marked complete
- **Search habits** – Find habits by query
- **Filter habits** – Narrow habit list by criteria
- **Sort habits** – Reorder habits by selected sort mode

### 🧠 V. Habit Tracking Use Cases

Habit check-in, logging, and consistency measurement operations:

- **Track daily habit** – Record daily cadence completion state
- **Track weekly habit** – Record weekly cadence completion state
- **Track monthly habit** – Record monthly cadence completion state
- **Track custom habit** – Record completion against custom cadence rules
- **Complete habit** – Mark scheduled habit instance complete
- **Skip habit** – Mark scheduled habit instance skipped intentionally
- **Miss habit** – Mark scheduled habit instance missed
- **Log habit note** – Record freeform context for a habit check-in
- **Log habit mood** – Record emotional state during check-in
- **Log habit effort** – Record perceived effort for completion
- **Log habit time** – Record time spent on habit execution
- **Log habit quantity** – Record measurable output amount
- **Track habit frequency** – Monitor cadence adherence frequency
- **Track habit consistency** – Monitor streak stability over time
- **Track habit completion rate** – Measure completion ratio over period

### 🧠 W. Habit Streak Use Cases

Streak lifecycle, risk management, and streak intelligence operations:

- **View current streak** – Display active streak length
- **View longest streak** – Display best historical streak length
- **View all streaks** – Display streak history across habits
- **Start streak** – Initialize a new streak run
- **Continue streak** – Extend streak with on-time completion
- **Break streak** – Record streak interruption event
- **Reset streak** – Reset streak counter to baseline
- **Restore streak** – Restore streak after approved recovery action
- **Track daily streak** – Track streak continuity on daily cadence
- **Track weekly streak** – Track streak continuity on weekly cadence
- **Track monthly streak** – Track streak continuity on monthly cadence
- **Track custom streak** – Track streak continuity on custom cadence
- **Celebrate streak milestone** – Trigger milestone celebration/reward flow
- **Detect at-risk streak** – Identify streak likely to break soon
- **Generate streak recovery plan** – Build plan to recover after disruption
- **Analyze streak performance** – Evaluate streak quality and trend
- **Forecast streak survival** – Predict probability of streak continuation

### 🧠 X. Habit Intelligence Use Cases

Advanced habit analysis, optimization, and recommendation operations:

- **Analyze habits** – Evaluate overall habit portfolio performance
- **Find best habit** – Identify top-performing habit
- **Find weakest habit** – Identify lowest-performing habit
- **Find most consistent habit** – Identify habit with strongest consistency trend
- **Find most impactful habit** – Identify habit with greatest positive outcome effect
- **Find keystone habit** – Identify habit with highest cross-domain leverage
- **Find habit conflicts** – Identify habits competing for time/energy/context
- **Find habit patterns** – Detect behavioral and timing patterns
- **Detect habit drop-off** – Identify decline in habit adherence
- **Detect habit burnout** – Identify strain/overload from habit regimen
- **Recommend new habit** – Suggest habit additions based on goals and gaps
- **Recommend habit adjustment** – Suggest cadence/scope changes for sustainability
- **Analyze habit goal alignment** – Evaluate habit support for active goals
- **Analyze future self habit alignment** – Evaluate habit alignment with desired identity

### 🧠 Y. Daily Planning Use Cases

Day-level planning, execution setup, and review operations:

- **Create daily plan** – Create a plan for the current day
- **Edit daily plan** – Modify daily plan contents
- **View daily plan** – Display today's planned structure
- **Complete daily plan** – Mark daily plan as completed
- **Reset daily plan** – Clear and restart today's plan
- **Generate daily plan** – Auto-generate today's plan from context
- **Review daily plan** – Reflect on planned vs completed outcomes
- **Prioritize daily plan** – Rank today's items by priority
- **Add task to today** – Add a task to today's plan
- **Add goal to today** – Add a goal focus to today's plan
- **Add habit to today** – Add a habit check-in to today's plan
- **Schedule focus block** – Allocate a dedicated deep-work block
- **Schedule break** – Allocate break/recovery intervals
- **Schedule routine** – Allocate routine sequence into the day plan

### 🧠 Z. Weekly Planning Use Cases

Week-level planning, review, and carry-forward operations:

- **Create weekly plan** – Create a plan for the current week
- **Edit weekly plan** – Modify weekly plan contents
- **View weekly plan** – Display current weekly structure
- **Complete weekly review** – Finalize weekly reflection workflow
- **Generate weekly priorities** – Produce ranked priorities for the week
- **Review weekly goals** – Evaluate goal progress in weekly context
- **Review weekly tasks** – Evaluate task execution for the week
- **Review weekly habits** – Evaluate habit adherence for the week
- **Analyze weekly progress** – Analyze overall weekly outcomes
- **Plan next week** – Draft upcoming week's plan
- **Carry over unfinished tasks** – Move incomplete tasks into next week
- **Detect weekly overload** – Identify unsustainable weekly workload

### 🧠 AA. Timeline Use Cases

Timeline visibility, event lifecycle, and temporal analysis operations:

- **View timeline** – Open the master timeline view
- **View daily timeline** – Display timeline scoped to today
- **View weekly timeline** – Display timeline scoped to current week
- **View monthly timeline** – Display timeline scoped to current month
- **View yearly timeline** – Display timeline scoped to current year
- **View goal timeline** – Display timeline filtered to goal events
- **View project timeline** – Display timeline filtered to project events
- **View habit timeline** – Display timeline filtered to habit events
- **Add timeline event** – Create a new timeline event
- **Edit timeline event** – Modify timeline event details
- **Delete timeline event** – Remove a timeline event
- **Track milestones** – Monitor milestone events on timeline
- **Track deadlines** – Monitor due-date/deadline events on timeline
- **Track completed events** – Monitor completed items over time
- **Analyze timeline** – Evaluate temporal patterns and distribution
- **Detect timeline conflict** – Identify overlapping or conflicting events
- **Detect timeline risk** – Identify schedule-risk windows and overload points
- **Forecast timeline outcomes** – Predict likely timeline completion outcomes

### 🧠 AA2. Reminder Use Cases

Reminder lifecycle and cross-domain reminder scheduling operations:

- **Create reminder** – Create a new reminder
- **Edit reminder** – Modify reminder details
- **Delete reminder** – Remove a reminder
- **Snooze reminder** – Delay reminder trigger time
- **Complete reminder** – Mark reminder as handled
- **View reminders** – View reminder list and states
- **Schedule task reminder** – Schedule reminder for task execution
- **Schedule habit reminder** – Schedule reminder for habit check-in
- **Schedule goal reminder** – Schedule reminder for goal action/review
- **Schedule streak reminder** – Schedule reminder to protect active streaks
- **Schedule review reminder** – Schedule generic review reminder
- **Schedule daily plan reminder** – Schedule reminder for daily planning flow
- **Schedule weekly review reminder** – Schedule reminder for weekly review flow

### 🧠 AA3. Notification Intelligence Use Cases

Intelligent notification delivery, alerting, and engagement operations:

- **Send smart reminder** – Send context-aware reminder at optimal timing
- **Send habit reminder** – Send habit-specific reminder notification
- **Send task reminder** – Send task execution reminder notification
- **Send goal reminder** – Send goal progress/action reminder notification
- **Send streak warning** – Send warning when active streak is at risk
- **Send milestone celebration** – Send celebration notification for milestones
- **Send overdue alert** – Send alert for overdue commitments
- **Send daily summary** – Send end-of-day summary notification
- **Send weekly summary** – Send end-of-week summary notification
- **Send motivation notification** – Send motivational reinforcement notification
- **Send coach recommendation** – Send coach-generated recommendation notification
- **Send SI insight** – Send SI-generated insight notification

### 🧠 AA4. Progress Reward Use Cases

Gamified progression, achievement, and unlock operations:

- **Earn XP** – Award experience points for completed actions
- **Earn badge** – Award a badge for milestone achievement
- **Earn streak badge** – Award a badge for streak milestones
- **Earn goal badge** – Award a badge for goal completion milestones
- **Earn habit badge** – Award a badge for habit adherence milestones
- **Earn task badge** – Award a badge for task execution milestones
- **Level up** – Advance user level based on accumulated XP
- **View achievements** – View earned achievements and badge history
- **View progress rewards** – View available and earned reward inventory
- **Unlock milestone** – Unlock milestone-based reward state
- **Unlock theme** – Unlock visual theme reward
- **Unlock coach message** – Unlock special coach message reward

### 🧠 AB. Health & Wellness Coach Use Cases

Personal wellness coaching, behavior support, and health-guidance operations:

- **Weight loss coaching** – Provide guidance for sustainable weight reduction
- **Weight gain coaching** – Provide guidance for healthy weight gain
- **Nutrition coaching** – Provide dietary guidance aligned with goals
- **Meal planning coaching** – Build practical meal plans for target outcomes
- **Hydration coaching** – Guide daily hydration habits and targets
- **Exercise coaching** – Guide balanced physical activity routines
- **Walking coaching** – Guide walking goals, cadence, and progression
- **Running coaching** – Guide running plans, pacing, and progression
- **Strength training coaching** – Guide resistance training structure and progression
- **Sleep coaching** – Guide sleep quality, schedule, and recovery habits
- **Energy coaching** – Guide strategies to stabilize and improve energy levels
- **Fatigue coaching** – Guide interventions to reduce fatigue and overload
- **Recovery coaching** – Guide rest and recovery protocols after exertion
- **Stress coaching** – Guide stress regulation techniques and routines
- **Burnout coaching** – Guide burnout prevention and recovery pathways
- **Healthy routine coaching** – Guide sustainable daily health routines

### 🧠 AC. Productivity Coach Use Cases

Performance coaching, execution support, and productivity behavior operations:

- **Focus coaching** – Guide attention management and concentration habits
- **Deep work coaching** – Guide sustained high-cognition work blocks
- **Time management coaching** – Guide allocation of time across priorities
- **Task prioritization coaching** – Guide ordering of tasks by impact and urgency
- **Procrastination coaching** – Guide interventions to reduce avoidance behavior
- **Distraction coaching** – Guide strategies to reduce interruption and context-switching
- **Planning coaching** – Guide practical planning routines and structures
- **Routine coaching** – Guide stable daily and weekly execution routines
- **Decision making coaching** – Guide structured decision processes under uncertainty
- **Work-life balance coaching** – Guide sustainable balance across life domains
- **Overwhelm coaching** – Guide load reduction and cognitive decompression strategies
- **Motivation coaching** – Guide intrinsic/extrinsic motivation reinforcement
- **Momentum coaching** – Guide consistency and forward-progress acceleration
- **Discipline coaching** – Guide commitment and follow-through systems
- **Consistency coaching** – Guide long-term behavior stability and repeatability

### 🧠 AD. Personal Growth Coach Use Cases

Identity development, emotional growth, and self-evolution coaching operations:

- **Confidence coaching** – Guide confidence-building behaviors and beliefs
- **Self-esteem coaching** – Guide healthier self-worth and self-talk patterns
- **Purpose coaching** – Guide discovery and articulation of personal purpose
- **Identity coaching** – Guide intentional identity design and alignment
- **Future self coaching** – Guide actions aligned with desired future identity
- **Life direction coaching** – Guide long-range life path clarification
- **Mindset coaching** – Guide adaptive mindset shifts and reframing
- **Resilience coaching** – Guide recovery and adaptation after setbacks
- **Emotional regulation coaching** – Guide emotional awareness and regulation skills
- **Self-care coaching** – Guide sustainable personal care rituals
- **Reflection coaching** – Guide structured reflection and learning loops
- **Values alignment coaching** – Guide decisions aligned with core values
- **Goal achievement coaching** – Guide strategic follow-through toward outcomes
- **Personal transformation coaching** – Guide long-term personal evolution pathways

### 🧠 AE. Smart Coach Intelligence Use Cases

Coach cognition, adaptive response generation, and recommendation tracking operations:

- **Detect user intent** – Infer user objective from context and inputs
- **Detect emotional state** – Infer user emotional state from language and signals
- **Detect coaching category** – Route request to best-fit coaching domain
- **Generate coaching response** – Produce context-aware coaching guidance
- **Generate action plan** – Produce structured next-step execution plan
- **Generate recovery plan** – Produce recovery strategy after setbacks
- **Generate motivation boost** – Produce motivation reinforcement prompts
- **Generate habit advice** – Produce habit-specific recommendations
- **Generate goal advice** – Produce goal-specific recommendations
- **Generate task advice** – Produce task-level execution recommendations
- **Ask follow-up question** – Ask clarifying question to improve guidance quality
- **Suggest next best action** – Recommend highest-impact immediate action
- **Save coach insight** – Persist meaningful coaching insight for later use
- **Track coach recommendation** – Track recommendation issuance and outcomes

### 🧠 AE2. Intent Detection Use Cases

Intent classification, routing, and fallback handling operations:

- **Detect smart coach intent** – Detect intent for Smart Coach interactions
- **Detect SI console intent** – Detect intent for SI Console interactions
- **Detect goal intent** – Detect goal-related intent from user input
- **Detect task intent** – Detect task-related intent from user input
- **Detect habit intent** – Detect habit-related intent from user input
- **Detect project intent** – Detect project-related intent from user input
- **Detect timeline intent** – Detect timeline-related intent from user input
- **Detect analytics intent** – Detect analytics/reporting intent from user input
- **Detect emotional intent** – Detect emotionally driven support intent
- **Detect planning intent** – Detect planning/scheduling intent
- **Detect unknown intent** – Detect unsupported or ambiguous intent
- **Route intent to handler** – Route classified intent to the correct handler
- **Fallback to general help** – Provide general-help fallback when routing confidence is low

### 🧠 AE3. Prompt & Response Use Cases

Prompt construction, context injection, response shaping, and validation operations:

- **Build smart coach prompt** – Build prompt template for Smart Coach flows
- **Build SI console prompt** – Build prompt template for SI Console flows
- **Build context-aware prompt** – Build prompt using active runtime context
- **Inject user context** – Inject user profile/state context into prompt
- **Inject goal context** – Inject goal context into prompt
- **Inject task context** – Inject task context into prompt
- **Inject habit context** – Inject habit context into prompt
- **Inject timeline context** – Inject timeline context into prompt
- **Format coach response** – Format Smart Coach response output
- **Format SI response** – Format SI Console response output
- **Generate follow-up question** – Generate clarification or continuation question
- **Generate structured action plan** – Generate structured step-by-step action plan
- **Validate AI response** – Validate AI response quality and schema compliance

### 🧠 AF. System Query Use Cases

Cross-domain retrieval, lookup, and status-inspection operations:

- **Query goals** – Retrieve goal records and goal states
- **Query tasks** – Retrieve task records and task states
- **Query projects** – Retrieve project records and project states
- **Query habits** – Retrieve habit records and habit states
- **Query timeline** – Retrieve timeline events and scheduling states
- **Query daily plan** – Retrieve current daily plan composition and status
- **Query weekly plan** – Retrieve current weekly plan composition and status
- **Query progress** – Retrieve progress metrics across active work
- **Query priorities** – Retrieve ranked priorities for execution
- **Query memories** – Retrieve stored memory/context artifacts
- **Query analytics** – Retrieve analytics summaries and trend outputs
- **Query recommendations** – Retrieve generated recommendation outputs

### 🧠 AG. SI Analysis Use Cases

System intelligence diagnostics, cross-domain analysis, and forecasting operations:

- **Analyze entire system** – Evaluate holistic system state and interactions
- **Analyze goals** – Evaluate goal portfolio quality and progress dynamics
- **Analyze tasks** – Evaluate task execution patterns and outcomes
- **Analyze projects** – Evaluate project delivery health and trajectory
- **Analyze habits** – Evaluate habit adherence quality and trends
- **Analyze timeline** – Evaluate temporal allocation and schedule structure
- **Analyze productivity** – Evaluate output, throughput, and efficiency signals
- **Analyze momentum** – Evaluate pace, continuity, and forward motion
- **Analyze consistency** – Evaluate reliability of execution over time
- **Analyze life balance** – Evaluate distribution across life domains
- **Analyze risk areas** – Identify high-risk domains and failure points
- **Analyze bottlenecks** – Identify constraints limiting system performance
- **Analyze progress trends** – Identify directional progress over time windows
- **Analyze future outcomes** – Forecast likely outcomes under current trajectory

### 🧠 AH. SI Recommendation Use Cases

System-intelligence recommendations, interventions, and optimization guidance operations:

- **Recommend next best action** – Recommend highest-impact immediate step
- **Recommend highest priority task** – Recommend top task by urgency and impact
- **Recommend most important goal** – Recommend goal with highest strategic value
- **Recommend habit to focus on** – Recommend habit with best leverage potential
- **Recommend project to advance** – Recommend project with strongest current ROI
- **Recommend recovery action** – Recommend corrective action after disruption
- **Recommend schedule adjustment** – Recommend timeline and calendar refinements
- **Recommend goal adjustment** – Recommend goal scope/timeline recalibration
- **Recommend productivity fix** – Recommend intervention to remove productivity drag
- **Recommend momentum boost** – Recommend action to restore forward velocity
- **Recommend risk reduction** – Recommend mitigations for identified risks

### 🧠 AI. SI Forecasting Use Cases

Predictive modeling, risk projection, and forward-outcome intelligence operations:

- **Forecast goal completion** – Predict likelihood and timing of goal completion
- **Forecast project completion** – Predict likelihood and timing of project completion
- **Forecast habit success** – Predict probability of sustained habit adherence
- **Forecast streak survival** – Predict continuation probability of active streaks
- **Forecast timeline risk** – Predict schedule instability and timeline risk exposure
- **Forecast productivity trend** – Predict near- and mid-term productivity trajectory
- **Forecast burnout risk** – Predict likelihood of burnout under current patterns
- **Forecast overload risk** – Predict likelihood of workload overload conditions
- **Forecast missed deadline** – Predict probability of missing upcoming deadlines
- **Forecast progress outcome** – Predict likely progress state at future checkpoints
- **Forecast future self alignment** – Predict alignment trajectory with desired identity

### 🧠 AJ. SI Console Natural Language Use Cases

Natural-language question answering flows for SI Console decision support:

- **Answer what should I do next** – Return immediate next best action
- **Answer what am I forgetting** – Surface missing, neglected, or hidden commitments
- **Answer what is overdue** – Surface currently overdue items
- **Answer what matters most** – Surface highest-impact priorities
- **Answer what is falling behind** – Surface slipping goals, projects, or habits
- **Answer what am I doing well** – Surface strengths and positive performance trends
- **Answer what needs attention** – Surface urgent focus areas
- **Answer what is my biggest risk** – Surface top current risk factor
- **Answer what is my biggest opportunity** – Surface top leverage opportunity
- **Answer am I on track** – Return trajectory assessment against goals and plans
- **Answer analyze my life** – Return holistic cross-domain life analysis
- **Answer summarize my system** – Return concise system-wide status summary

### 🧠 AK. Memory System Use Cases

Memory lifecycle, contextual linking, retrieval, and memory-intelligence operations:

- **Create memory** – Add a new memory record
- **Edit memory** – Modify memory content and metadata
- **Delete memory** – Permanently remove a memory record
- **Archive memory** – Move memory out of active recall scope
- **View memories** – Browse memory records
- **Search memories** – Retrieve memories by query
- **Tag memory** – Apply labels for memory categorization
- **Link memory to goal** – Associate memory with a goal
- **Link memory to task** – Associate memory with a task
- **Link memory to habit** – Associate memory with a habit
- **Link memory to project** – Associate memory with a project
- **Generate memory summary** – Produce concise summary of stored memories
- **Recall relevant memory** – Surface context-relevant memory during decision flow
- **Analyze memory patterns** – Detect recurring themes and behavioral patterns

### 🧠 AL. Journal Use Cases

Journal entry lifecycle, reflective capture, and insight-generation operations:

- **Create journal entry** – Create a new journal record
- **Edit journal entry** – Modify journal entry content
- **Delete journal entry** – Permanently remove a journal entry
- **View journal entry** – Open a specific journal entry
- **Search journal entries** – Find entries by query and filters
- **Tag journal entry** – Apply labels to organize entries
- **Add mood to entry** – Record emotional state with an entry
- **Add goal reflection** – Record reflection related to goals
- **Add habit reflection** – Record reflection related to habits
- **Add daily reflection** – Record end-of-day reflection
- **Add weekly reflection** – Record end-of-week reflection
- **Analyze journal sentiment** – Detect sentiment and emotional trends
- **Generate journal insight** – Produce insights from journal patterns
- **Generate reflection prompt** – Generate prompts for deeper reflection

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

ChronoSpark implements a **subscription-only, no-ads, premium-focused monetization model** with two tiers: **Base (Free)** and **Premium**. The system uses mock billing for development and integrates cleanly with existing architecture.

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

### How It Works

1. **Base users** get trial quotas (5 + 8 opens)
2. When trials exhaust → `PremiumFeatureGate` prompts upgrade
3. **Upgrade flow** is non-intrusive, available in Settings
4. **Premium users** bypass all quotas and get full feature access
5. **Downgrade** at any time, keeps all data intact
6. **Refund eligible** for 14 days after signup (mocked)

### Technical Implementation

**Subscription Fields in AppState**:
```dart
late SubscriptionSnapshot _subscription;
SubscriptionPlan get currentPlan => _subscription.plan;
bool get isPremium => _subscription.plan.isPremium;
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

**Adaptive Learning Scaling**:
- Base: 7-day retention, 0.6x learning depth
- Premium: 30-day retention, 1.0x learning depth

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

