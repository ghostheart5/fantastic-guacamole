# ChronoSpark Roadmap

This document outlines the planned development trajectory for ChronoSpark — from near-term improvements to long-range vision.

---

## Upcoming Features

### Data Layer Upgrade
- Migrate `RuntimePersistence` from `SharedPreferences` to **Hive** or **SQLite** for richer querying, relational data, and larger datasets
- Add schema migration tooling to handle version upgrades gracefully across existing installs

### Full Entity Model Implementation
- **Projects** — Group tasks into named containers with status tracking
- **Subtasks** — Break complex tasks into trackable sub-items
- **Milestones** — Checkpoint markers within goals
- **Habits** — Recurring behavior tracking (e.g., "exercise 3×/week") with streak counters
- **Tags & Categories** — Flexible labeling and organizational grouping across all entity types

### Scheduling Enhancements
- **WorkWindow** — Flexible time slots auto-filled by the SI engine with suitable tasks
- **Recurring Events** — Repeat rules for events and routines (daily, weekly, custom cadence)
- **Deadline Propagation** — Automatically surface and escalate approaching deadlines across linked tasks and goals

### SI Engine Improvements
- **Rule Engine** — User-defined conditional logic: `IF energy < 30% → schedule lighter tasks`
- **Automation Triggers** — Time- or event-driven actions: `WHEN 9 AM → start focus session`
- **Natural Language Task Parsing** — Parse free-text input such as "do homework tomorrow at 5 pm" into structured tasks
- **Recovery Planning** — Detect missed or skipped tasks and intelligently reschedule them

### UI & Experience
- **Kanban Board View** — Bucket/column layout (Backlog → In Progress → Done)
- **Constellation Task Web** — Visual graph of task dependencies and relationships
- **ArcView Calendar Improvements** — Enhanced circular calendar with collision handling and priority overlays
- **Focus Session Mode** — Timed work blocks with a distraction-minimizing overlay and state-aware task suggestion

### Analytics & Insights
- **Productivity Dashboard** — Completion rate, consistency score, streak visualization
- **Behavioral Heatmap** — Hourly and daily activity patterns inferred from the adaptive learning system
- **Life Replay** — Playback of a day's log entries as a timeline review
- **Performance Metrics** — Per-task and per-project effort and velocity tracking

---

## Long-Term Goals

### Cloud Sync & Multi-Device Support
- Introduce a **Workspace** model enabling state synchronization across devices
- Firebase Firestore backend integration for real-time sync, with local-first offline support
- Conflict resolution strategy for concurrent edits across devices

### Account & Identity
- Full user authentication via Firebase Auth (email/password, Google sign-in)
- Per-user profile, preferences, and notification settings persisted server-side
- Device-agnostic trial and premium status validation

### Cross-Platform Expansion
- Stable, fully-tested releases for **Android**, **iOS**, **macOS**, and **Windows**
- Responsive layout system adapting to phone, tablet, and desktop form factors
- Platform-specific integrations: system calendar (Android/iOS), native notifications (desktop)

### AI-Powered Scheduling
- Deep SI Engine evolution: move from rule-based scoring to a learned model trained on aggregated (anonymized) behavioral data
- Goal-aware auto-planner: given a set of goals and available time windows, generate an optimized weekly schedule
- Contextual suggestions driven by time of day, recent behavior, and predicted energy curves

### Integrations & Ecosystem
- Calendar sync with Google Calendar and Apple Calendar
- Import/export tasks from popular formats (CSV, Markdown, Todoist, Notion)
- Public plugin/extension API for third-party integrations

### Monetization & Subscription Evolution
- Refined subscription tiers (Base → Premium → Ultimate) with clearly scoped feature sets
- Server-side receipt verification for in-app purchases (iOS/Android)
- Team/organization plan for shared workspaces and collaborative task management

### Accessibility & Localization
- Full WCAG 2.1 AA compliance across all screens
- RTL layout support
- Localization infrastructure with initial support for Spanish, French, and Portuguese

---

## Version Milestones

| Milestone | Focus |
|-----------|-------|
| **v1.x** | Stabilize core task management, fix persistence edge cases, expand test coverage |
| **v2.0** | Full entity model (projects, subtasks, habits, milestones), Hive persistence, rule engine |
| **v2.x** | Cloud sync, Firebase Auth, multi-device support |
| **v3.0** | AI scheduling, cross-platform polish, integrations, team plan |

---

*This roadmap reflects current intentions and will evolve as priorities shift. Contributions and feedback are welcome — see [CONTRIBUTING](CODE_OF_CONDUCT.md) for community guidelines.*
