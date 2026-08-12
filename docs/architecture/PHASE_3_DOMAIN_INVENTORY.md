# Phase 3 Domain Inventory

| Structure | Representative paths | Concepts | Persistence / status |
| --- | --- | --- | --- |
| Entities and value objects | `lib/domain/entities/{goal,task,habit,plan,note,timeline_event,settings,progression}_entity.dart`; `lib/domain/value_objects/priority.dart` | Core life records | Active candidate; several parallel forms |
| Use cases and interfaces | `lib/domain/usecases/`; `lib/domain/interfaces/i_*_repository.dart` | CRUD, completion, timeline, progression | Active candidate |
| Implementations | `lib/data/repositories/{goal,task,habit,plan,timeline,settings,memory,log,si_engine}_repository.dart` | Reads/writes | Mixed Hive, SharedPreferences, SecureStore and backup/sync |
| Storage and mapping | `lib/data/storage/{hive_service,hive_boxes,shared_prefs_service,secure_store}.dart`; `lib/data/local/task_entity_mapper.dart` | Serialization | Active, multi-store |
| Presentation state | `lib/state/providers/{task,goals,habits,creator,timeline,progression,emotion,si_pipeline}_provider.dart`; controllers | Feature read models and derivations | Active but not a single truth boundary |
| Feature entry points | `lib/features/{creator,timeline,progression,nexus,si_console,emotion}/` | Capture and display | Consumers; some own local models |
| Remote/schema | `supabase/migrations/`; remote gateways and sync services | Identity, metrics, backups, monetization | Core life records remain primarily local-first |

Dependencies flow imperfectly among domain entities, repository implementations, Riverpod state, UI, and SI/trajectory derivations. `NoteEntity`, `TaskEntity`, task view `Task`, routine/habit forms, Timeline events, logs, memories, and workspace/SI payloads are the principal overlapping representations.
