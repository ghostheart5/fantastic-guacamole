# SI Console

SI Console is Axiomara's deeper decision and investigation workspace. Smart Planner focuses on making a workable plan; SI Console examines the structure of a situation: evidence, intent, competing objectives, uncertainty, risk, and possible outcomes.

## When to use it

Use SI Console when the question is larger than “what should I do next?”

- Which commitment is creating the most pressure, and why?
- What is blocking progress toward this goal?
- Which scenario protects both the deadline and my available Energy?
- What changed in my Trajectory after I delayed this task?
- Which assumption should I verify before making this decision?

## Query controls are part of the question

The Console's mode, entity filters, scenario selection, and time horizon define the analysis. Selecting **Tasks** should ground the response in relevant tasks. Selecting a goal should change the decision frame. Changing a scenario should compare the chosen scenario rather than repeat a default answer.

When a control does not affect the available evidence, SI Console should say so. It should never pretend a filter worked while silently ignoring it.

## Response anatomy

A strong SI response separates:

1. **Intent** — the decision the user is actually trying to make.
2. **Evidence** — the records, history, and signals available for this query.
3. **Interpretation** — what the evidence may mean and where it conflicts.
4. **Options** — meaningful alternatives with trade-offs.
5. **Recommendation** — the best-supported next move, if one exists.
6. **Uncertainty** — missing, stale, or inferred information.
7. **Control** — the action remains with the user.

## Advanced analysis

Advanced mode should increase analytical depth, not simply make the answer longer. It may compare alternatives, identify dependencies, test assumptions, or connect Timeline, Trajectory, Progression, and operating signals. The response must remain readable and traceable to evidence.

## Memory and continuity

Conversation memory exists to preserve the current decision thread. It should remember relevant prior questions and corrections without treating unrelated old conversations as current truth. The user should be able to begin a fresh analysis when the context changes.

## Honest failure

“I cannot answer yet” is useful only when followed by a precise reason and next step. SI Console should name the unavailable source, missing entity, or ambiguous intent and ask for the smallest fact needed to continue.

## Safety boundary

SI Console is decision support, not autonomous authority. It does not silently modify records or guarantee outcomes. It is not a substitute for medical, legal, financial, emergency, or other qualified professional help.

## Related pages

- [[Smart Planner]]
- [[Nexus]]
- [[Trajectory Engine]]
- [[Progression]]
- [[Creator]]
- [[Timeline]]
