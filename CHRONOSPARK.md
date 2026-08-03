# ChronoSpark

ChronoSpark is the product architecture behind fantastic-guacamole: a Flutter-based personal operating system for planning, reflection, execution, and momentum. The experience is designed to feel like a mission-control layer for daily life: decisive, readable, and focused on what matters now.

## Product intent

ChronoSpark is built to feel like a futuristic command surface for personal momentum:

- help the user understand what matters today at a glance
- surface structure and guidance without overwhelming the experience
- support fast creator workflows for tasks, notes, goals, and daily rhythms
- frame the app as a living operating system rather than a generic to-do list
- keep onboarding, preferences, reminders, and permissions intuitive and visible

## Current product scope

The app now centers on a small set of high-value experiences:

- Nexus as the central daily briefing and overview surface
- Creator as the rapid entry point for tasks, notes, goals, and daily rhythms
- SI Console as the mission-control guidance layer for coaching and action framing
- Timeline and planning surfaces for sequence-based thinking over time
- Profile, settings, and permissions for preference controls, reminders, and access management

## What changed in the current product direction

The recent product work has pushed the app toward a clearer and more cohesive experience:

- Nexus now functions as the main daily overview rather than a generic home screen
- SI Console has been reframed as a strategic command layer with sharper response framing
- Creator now supports a compact quick-entry experience with clearer entry-type guidance
- Daily rhythms replace older habit framing in the creator flow to make the concept easier to understand
- Settings now surface reminder automation, notification permissions, and voice access more clearly
- Profile has been simplified to reduce clutter and keep the experience more focused

## Architecture overview

### Core stack

- Flutter with Dart
- Riverpod for state management and provider-driven orchestration
- SharedPreferences, Hive, and local persistence layers for runtime state and offline resilience
- Material 3 styling with custom animated UI, neon visual treatments, and mission-control inspired layouts
- Firebase, Supabase, and app-level integrations for auth, storage, notifications, and runtime services

### Layering model

The intended dependency direction is:

UI -> State/Providers -> Repositories/Data Access -> Services/Integrations -> Engine/Domain Logic

This contract is documented in [docs/LAYER_FLOW.md](docs/LAYER_FLOW.md).

## Primary app layers

### 1. UI layer

The UI layer lives under [lib/ui](lib/ui) and [lib/features](lib/features). It contains the visible product experience: Nexus, Creator, SI Console, onboarding, settings, profile, and premium-related surfaces.

Key responsibilities:

- render the user-facing planner experience
- connect screens to providers and runtime state
- present guidance, reminders, and onboarding in a more legible way
- maintain a visually cohesive and readable product language

### 2. State layer

The state layer lives under [lib/state](lib/state) and [lib/core/state](lib/core/state). This is the runtime orchestration layer for planning, reminders, permissions, and app flow state.

Key responsibilities:

- own the active planning context and user state
- coordinate task, note, goal, daily rhythm, and decision lifecycle events
- connect UI actions to engine-level logic
- persist and restore runtime state across sessions

### 3. Domain and engine layer

The domain and engine logic lives under [lib/domain](lib/domain), [lib/core](lib/core), and [lib/engine](lib/engine). This is where guidance logic, planning heuristics, reminders, and system behavior live.

Key responsibilities:

- generate contextual recommendations and planning hints
- adapt suggestions to user behavior and timing patterns
- manage reminder and notification-related logic
- support planning and planning heuristics

### 4. Data and integration layer

The data layer is organized under [lib/data](lib/data) and [lib/config](lib/config), with supporting runtime integrations for Firebase, Supabase, persistence, and external services.

Key responsibilities:

- load and persist user and runtime data
- integrate with remote services when present
- support feature flags, environment configuration, and build-time setup
- keep app logic separate from concrete storage and service details

## Main product areas

### Nexus

Nexus is the central daily briefing surface. It is designed to answer the question “what matters today?” quickly and clearly, with a more focused top-of-fold experience.

### Creator

Creator is the fast input surface for structured planning. It enables rapid capture of tasks, notes, goals, and daily rhythms and helps the user move from intention to record without friction.

### SI Console

The SI Console is the app’s guidance and coaching surface. It turns the current planning context into action-oriented support and is framed as a mission-control layer for decision-making.

### Timeline and planning

Timeline and planning surfaces support time-blocking, milestone thinking, and sequence-oriented planning. These experiences are intended to help the user think in sequences, not just static lists.

### Profile, settings, and permissions

Profile, settings, and permission flows provide account context, reminders, notification access, voice access, and app controls in a way that is more visible and easier to understand.

## Key domain concepts

- task: a concrete unit of work or action
- note: a lightweight capture for ideas, context, or reflection
- goal: a target outcome or direction for effort
- daily rhythm: a recurring pattern or behavior that should be supported regularly
- mission: a higher-level objective or grouping of work
- timeline: an ordered view of planned time and effort
- decision: an output or recommendation produced by the system
- log: an audit trail of events and support actions
- preference: a user-specific setting that changes experience behavior

## Runtime behavior

ChronoSpark is organized around a few repeated runtime loops:

1. collect user activity and current planning context
2. evaluate task pressure, timing, and intent
3. produce guidance, reminders, or planning suggestions
4. present those outputs through Nexus, Creator, and the SI Console
5. persist the resulting state for the next session

This loop is what makes the app feel like a system rather than a static planner.

## Repository map

- [lib](lib) contains the app implementation and feature modules
- [assets](assets) holds UI assets, animations, tutorials, and seed content
- [test](test) and [integration_test](integration_test) contain automated tests and smoke coverage
- [docs](docs) contains architecture notes, audits, and release guidance
- [supabase](supabase) holds integration assets and edge function support

## Release and engineering notes

The project includes a substantial audit and release documentation set in [docs](docs), including architecture review, release readiness, and testing information. These docs should be treated as companion material to this overview rather than as the only source of truth.

## Summary

ChronoSpark is best understood as a layered, product-first planning system: a polished app shell wrapped around adaptive logic, structured planning concepts, and a long-term roadmap for everyday command-center experiences.
