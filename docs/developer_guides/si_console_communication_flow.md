# SI Console communication flow

The shipping SI Console is a deterministic, read-only guidance surface. Its current route is:

1. `SIConsoleScreen` validates typed or dictated input and preserves up to four recent user turns.
2. `SIV2Query.fromUserInput` resolves intent, sources, local time range, entity filter, scenario assumption, exclusions, capacity, and requested delay.
3. `SIV2QueryService` reads an account-fenced snapshot through `SIV2ReadGateway`.
4. `SIV2Engine` resolves one subject, applies local-calendar semantics, and creates observed, calculated, inferred, missing, scenario, confidence, and recommendation sections.
5. An `OperatingDecisionReceipt` may augment the response only when its subject evidence and displayed label agree with the resolved answer.
6. The typed contract validates identities and structure. Semantic regression tests separately assert records, constraints, time horizon, language, and cross-section meaning.
7. `SIConsoleScreen` renders the result. It does not create, complete, reschedule, delete, purchase, or publish anything.

The Console reads tasks, goals, milestones, Timeline records, and explicitly permitted Person Context. Notes and Daily Rhythms are outside its direct evidence contract. Unavailable sources and empty relevant evidence are distinct states.

The older `AIController`, agent orchestration, `SIAIService`, `SIEngineService`, `SyntheticIntelligenceEngine`, and cognitive/soul compatibility layers are not the SI Console execution route. They must not be cited as evidence of Console capability. Compatibility paths may only be reconnected after equivalent bilingual semantic and account-boundary tests.

Conversation messages are screen-local. The displayed Console does not claim durable conversational memory. Evidence references are shown as record identifiers; guidance is not an action receipt.

See `docs/audits/2026-09-14-si-console-human-use-audit.md` and the current SI V2 regression suites for acceptance evidence.
