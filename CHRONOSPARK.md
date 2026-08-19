# ChronoSpark Product and Architecture Overview

ChronoSpark is a planning and decision-support system that connects planning inputs, scheduled action, available guidance, forward-looking scenarios, and evidence-backed progress.

The product helps people understand the day, decide the next move, and maintain momentum while keeping the user responsible for every decision.

## Product operating model

ChronoSpark turns information into useful action through connected, non-mandatory stages:

```text
Capture → Schedule → Understand → Plan → Investigate → Anticipate → Advance
```

The first-use path is:

```text
Creator → Timeline → Nexus
```

After activation, the features remain connected capabilities rather than a required linear sequence.

## Current feature canon

### Nexus

Nexus is the main and home surface. It presents the current operating state, relevant limitations, and a next-best action for the user to review.

### Creator

Creator owns structured planning inputs. It is where tasks, goals, Daily Rhythms, and notes are created and managed. Timeline is their scheduling projection rather than a second authoring surface.

### Timeline

Timeline plans and reviews scheduled action, operational sequencing, and history across time.

### Smart Planner

Smart Planner provides explainable planning assistance and reconciles available goals, tasks, schedules, constraints, and priorities. Its output is guidance to evaluate.

### SI Console

SI Console supports deeper strategic investigation. It presents relevant context, limitations, and executable guidance without replacing the user's judgment.

### Trajectory Engine

Trajectory Engine compares explicit future scenarios, assumptions, trade-offs, and possible corrections. It is decision support, not a prediction or promise.

### Progression

Progression presents evidence-backed advancement and leverage-action context. Levels, experience, streaks, momentum, and confidence are product signals—not guarantees or judgments of personal worth.

## Core planning records

- **Task** — a specific action the user intends to complete.
- **Goal** — a desired outcome or longer-term direction.
- **Daily Rhythm** — a repeatable behavior practiced consistently.
- **Note** — context, information, research, ideas, decisions, or reflection.

These records can support one another, but they do not automatically become a schedule, recommendation, or commitment.

## Product boundaries

- Nexus is the home surface.
- Signal is an output from Smart Planner or SI Console, not a standalone feature.
- Daily Rhythms is the current public term for recurring behaviors.
- Reflection is the current public term for reviewing and retaining useful experience.
- Smart Planner and SI Console provide guidance, not automatic authority.
- Trajectory Engine presents scenarios, not guaranteed predictions.
- Progression reports available evidence, not personal value.
- ChronoSpark does not replace professional medical, legal, financial, emergency, or other qualified advice.

## Architecture

### Core stack

- Flutter and Dart
- Riverpod for state management and orchestration
- Supabase Auth, Postgres, Storage, and Edge Functions for primary cloud services
- Firebase Cloud Messaging, Analytics, and Crashlytics for notifications and telemetry
- Local account-scoped persistence for offline continuity and recovery

### Dependency direction

```text
UI → State and Providers → Repositories and Data Access → Services and Integrations → Domain and Engine Logic
```

The detailed dependency contract is maintained in [docs/LAYER_FLOW.md](docs/LAYER_FLOW.md).

### Primary source areas

- `lib/features/` and `lib/ui/` contain product surfaces and shared presentation components.
- `lib/state/` contains providers, controllers, and runtime orchestration.
- `lib/data/` contains repositories, persistence, and service integration boundaries.
- `lib/domain/`, `lib/core/`, and `lib/engine/` contain entities, contracts, and decision-support logic.
- `supabase/` contains database migrations and Edge Function sources.
- `test/` and `integration_test/` contain automated verification.

## Data and intelligence principles

- Account-owned data must remain isolated by verified authenticated scope.
- Missing, stale, loading, offline, and error states must not be represented as healthy or complete evidence.
- Recommendations should identify relevant context and limitations.
- User-authored content should not be sent to remote intelligence services unless the applicable privacy policy and user control permit it.
- Creation, scheduling, progression, and trajectory claims must be backed by real persistence and domain behavior.

## Current public product documentation

The [ChronoSpark GitHub Wiki](https://github.com/ghostheart5/fantastic-guacamole/wiki) is the current public product guide. In particular, see:

- [Overview](https://github.com/ghostheart5/fantastic-guacamole/wiki/Overview)
- [Core Concepts](https://github.com/ghostheart5/fantastic-guacamole/wiki/Core-Concepts)
- [Daily Workflow](https://github.com/ghostheart5/fantastic-guacamole/wiki/Daily-Workflow)
- [Trajectory Engine](https://github.com/ghostheart5/fantastic-guacamole/wiki/Trajectory-Engine)
- [Progression](https://github.com/ghostheart5/fantastic-guacamole/wiki/Progression)
