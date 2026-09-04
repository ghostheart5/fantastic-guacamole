# Priority 7 File Responsibility Map

Point-in-time scope: the uncommitted Windows working tree based on
`6ed43fff58d861072368629f35ce932087cfc601`. The splits were mechanical: existing
declarations moved into Dart `part` files and public behavior was not redesigned.

| Binder target | Before | Coordinator now | Responsibility parts |
| --- | ---: | ---: | --- |
| Settings | 2,903 | `settings_screen.dart` — 1,171 | planning 700; person context 710; governance 526; data 505; shared widgets 466; compatibility shell 3 |
| SI Console | 2,282 | `si_console_screen.dart` — 915 | response and command widgets 1,370 |
| Smart Planner screen | 2,520 | `smart_planner_screen.dart` — 1,415 | presentation and input widgets 1,108 |
| Smart Planner query controller | 2,373 | `smart_planner_query_controller.dart` — 1,252 | parsing, evidence, and response support 1,124 |
| Timeline | 1,987 | `timeline_screen.dart` — 435 | projections, dialogs, and view widgets 1,555 |
| Trajectory Engine screen | 1,943 | `trajectory_engine_screen.dart` — 329 | overview and composer 712; state and detail widgets 907 |
| Nexus widget library | 1,631 | `nexus_screen.dart` — 320 | header and focus widgets 773; timeline and learning widgets 859 |
| Backup service | 1,693 | `backup_service.dart` — 1,553 | backup envelope and rollback models 143 |
| Google Play repository | 1,757 | `google_play_paywall_repository.dart` — 1,277 | transaction support 310; persistence support 186 |
| Domain use-case composition | 940 | `domain_usecase_providers.dart` — 142 | repositories 221; core 229; lifecycle 129; timeline 114; notes and SI 116 |

`test/architecture/file_responsibility_contract_test.dart` requires every named
coordinator and part to exist, remain connected by `part`/`part of`, and remain
at or below 1,600 lines. This limit applies to the ten libraries named above.
At this snapshot no Dart source file exceeds that ceiling. The ceiling is a
navigability guard, not proof that a library is behaviorally or architecturally
correct; dependency direction is enforced separately by `check_architecture.ps1`.
