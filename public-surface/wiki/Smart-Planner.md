# Smart Planner

Smart Planner is Axiomara's conversational planning surface. It turns a real question, selected records, schedule constraints, and current operating signals into a practical answer that can be challenged and refined.

## What to ask

Strong questions name a decision and provide the context that matters:

- “What time should I go to the store? Use my grocery task and today's schedule.”
- “Build a realistic plan for finishing this proposal before Friday.”
- “My Energy is low. Which two tasks protect the most important goal?”
- “Move this routine without breaking the commitments already on my Timeline.”

## What a strong response contains

For the grocery example, a useful response might be:

> **Recommended window: 6:10–6:55 p.m.** Your grocery task is still open, the schedule shows a clear window after the 5:30 commitment, and the next fixed item begins at 7:20. This assumes about 15 minutes of travel each way. If traffic is heavier or the store closes early, leave at 5:55 instead.

The answer is useful because it provides:

- a specific recommendation;
- the task and schedule evidence that shaped it;
- the constraint that protects the rest of the day;
- an explicit travel-time assumption; and
- an alternative when the assumption changes.

## Attach context deliberately

Planner can reason more precisely when you attach the relevant task, goal, note, Daily Rhythm, or Timeline context. Attaching an item does not give permission to change it. It makes the item available to the current planning question.

If you change the selected item, date, scenario, or query controls, Planner should evaluate the changed request. If the new context does not affect the conclusion, the response should explain why.

## Follow-up conversation

Follow-ups refine the active plan:

```text
You: What time should I go to the store?
Planner: 6:10 p.m., based on the open window after your 5:30 commitment.
You: What if traffic is worse after 6?
Planner: Leave at 5:55, or use the 7:35 window if the store remains open.
```

A follow-up should carry forward the relevant records and constraints. Starting a new conversation clears that decision thread.

## From answer to action

Planner proposes. You decide. A plan becomes a saved or scheduled change only through a clear user action. Review dates, duration, dependencies, and conflicts before applying anything.

## When Planner cannot answer

A useful failure names what is missing: for example, no date on the task, an unavailable schedule, or an ambiguous deadline. It should ask for the smallest missing fact rather than returning the same generic response to every question.

## Boundaries

Planner does not guarantee an outcome and is not professional medical, legal, financial, or emergency advice. It may be wrong when records are incomplete, stale, or misunderstood.

## Related pages

- [[Creator]]
- [[Timeline]]
- [[Nexus]]
- [[SI Console]]
- [[Trajectory Engine]]
