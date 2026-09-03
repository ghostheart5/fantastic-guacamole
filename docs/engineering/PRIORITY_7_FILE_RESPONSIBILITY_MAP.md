# Priority 7 File Responsibility Map

Point-in-time scope: the uncommitted Windows working tree based on
`bc414f2dd851bba18570ec12e27d830b62fd10fb`. The split was mechanical: existing
declarations moved into Dart `part` files and public behavior was not redesigned.

| Binder target | Before | Coordinator now | Responsibility parts |
| --- | ---: | ---: | --- |
| Settings | 2,903 | `settings_screen.dart` — 1,171 | planning 700; person context 710; governance 526; data 505; shared widgets 466; compatibility shell 3 |
| SI Console | 2,282 | `si_console_screen.dart` — 915 | response and command widgets 1,370 |
| Smart Planner query controller | 2,373 | `smart_planner_query_controller.dart` — 1,252 | parsing, evidence, and response support 1,124 |
| Timeline | 1,987 | `timeline_screen.dart` — 435 | projections, dialogs, and view widgets 1,555 |

`test/architecture/file_responsibility_contract_test.dart` requires every named
coordinator and part to exist, remain connected by `part`/`part of`, and remain
at or below 1,600 lines. This limit applies to the four files named by the
Priority 7 binder. Other large touched files are not silently certified by this
map: `smart_planner_screen.dart` (2,520), `trajectory_engine_screen.dart`
(1,943), and `nexus_screen.widgets.dart` (1,630) remain follow-up decomposition
candidates.
