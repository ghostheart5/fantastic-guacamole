# Phase 3 Repair Backlog — Do Not Implement in Phase 3

| ID | Group | Problem / desired architecture | Severity | Tests / history review |
| --- | --- | --- | --- | --- |
| HLM-01 | A | Define canonical aggregate policy for task, note, habit, routine, and plan intake. | P1 | Lifecycle and migration tests; review backup/form branches |
| HLM-02 | A | Define typed history facts versus derived Timeline projections. | P1 | Event round-trip/consumer tests; review timeline branches |
| HLM-03 | B | Create an intervention-outcome domain contract before claiming accepted/dismissed history. | P1 | Persistence, controls, and explanation tests |
| HLM-04 | C | Specify a shared planner-input/read-model boundary. | P2 | Creator-to-planner/Nexus continuity tests |
| HLM-05 | C | Establish a canonical progress calculation contract. | P2 | Cross-feature metric consistency tests |
| HLM-06 | D | Route preference ownership through a documented settings boundary. | P2 | Preference propagation tests |
| HLM-07 | E | Resolve `TaskEntity` versus `Task` read-model responsibilities. | P3 | Mapper and repository contract tests |
| HLM-08 | E | Separate Timeline facts from risk/recommendation/forecast projections. | P3 | Timeline source/type tests |
| HLM-09 | F | Classify deleted and backup code before any cleanup. | P2 | Phase 2 snapshot comparison; branch review required |
| HLM-10 | F | Review unique branch history for alternative implementations before extraction. | P2 | Isolated branch test plan |
