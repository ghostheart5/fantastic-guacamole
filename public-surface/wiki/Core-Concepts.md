# Core Concepts

## The decision graph

Axiomara treats planning as a connected graph rather than a pile of unrelated entries.

```text
Goal ──gives direction──▶ Task ──occupies time──▶ Timeline
  │                         │                         │
  └──supported by──▶ Daily Rhythm                   │
                            ▲                        │
Note ──adds context─────────┴────────────────────────┘
```

Connections are useful only when they remain understandable. A note does not silently become a task. A recommendation does not silently become a commitment. The record owner stays visible.

## Context is selected, not assumed

Smart Planner and SI Console should use the context attached or permitted for the current question. Filters, selected entities, scenario controls, and follow-up conversation are part of the request. Changing them should be capable of changing the answer when they change the evidence.

## Energy, Clarity, and Momentum

These signals describe different dimensions:

- **Energy:** “How much realistic capacity appears available?”
- **Clarity:** “How well is the next decision understood?”
- **Momentum:** “Is recorded follow-through accumulating?”

They should not be collapsed into one vague wellness score. A person can have high clarity and low energy, or strong momentum while facing a difficult decision. Nexus and Trajectory use the combination to frame the next move.

## Explainability contract

A recommendation is explainable when a user can answer:

1. What did the system use?
2. What did it infer?
3. Why did this option rank above the alternatives?
4. What could make the answer wrong?
5. What, if anything, will change if I accept it?

If evidence is missing, Axiomara should ask a useful question or name the limitation. It should not hide uncertainty with generic confidence.

## Conversation continuity

A follow-up belongs to the active decision thread. It should retain the relevant question, selected records, earlier answer, and newly supplied constraint. Users can start a fresh question when they want a new context.

## Scenario versus action

A scenario is a possibility to inspect. It does not change the Timeline or any record. An action is a user-approved change in the product. Keeping those concepts separate allows ambitious exploration without accidental commitments.

## Progress without manipulation

Experience, levels, streaks, and Momentum exist to make recorded progress visible. They are not advertisements, gambling mechanics, or judgments about a person's worth. Axiomara contains no ads and never requires a user to watch one.

## Related pages

- [[Creator]]
- [[Timeline]]
- [[Nexus]]
- [[Smart Planner]]
- [[SI Console]]
- [[Trajectory Engine]]
- [[Progression]]
