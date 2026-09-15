# SI Console acceptance checklist

The current Console is accepted only when executed responses establish all of the following:

- Exact task, goal, or milestone questions keep one resolved subject across the direct answer, recommendation, scenarios, and evidence links.
- Explicit exclusions never become recommendations.
- Priority requests rank priority before date; overdue lookup is distinct from comparison.
- Scheduled and due timestamps remain separate and use the person's local calendar.
- Capacity and requested scenario duration are honored or explicitly reported unsupported.
- English and Spanish welcome questions, ordinary questions, corrections, negation, and follow-ups have equivalent intent and fully localized generated output.
- Missing records, unavailable sources, and empty relevant evidence produce different confidence wording.
- Unsupported questions contain no unrelated calculations, inferences, scenarios, or actions and offer a supported next question.
- Shared decision receipts are rejected when subject identity or displayed labels disagree.
- The screen remains read-only and does not imply that a recommendation changed stored data.

Current direct evidence sources are tasks, goals, milestones, Timeline, and permitted Person Context. Notes, Daily Rhythms, durable chat memory, external-model reasoning, and calibrated real-world prediction are outside the current Console contract.

Structural `validate()` success is necessary but does not establish semantic correctness. Acceptance requires composed-service and UI assertions over the displayed response in addition to engine unit tests.
