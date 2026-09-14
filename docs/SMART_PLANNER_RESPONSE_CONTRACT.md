# Smart Planner response contract

The September 13, 2026 audit of build 2026083039 identified response understanding, conversation state and presentation defects. This document describes the authorized repair standard; it is not a device-validation or release certificate.

## Understanding and constraints

- Preserve the full user objective independently of display-length limits. A duration-only correction updates the time constraint rather than becoming a new task.
- Respect explicit exclusions and practical constraints. The word “restaurant” does not mean the user needs rest; unavoidable caregiving interruptions require interruptible work.
- Distinguish deadlines from available working time. A shift starting in 30 minutes does not establish that all 30 minutes are available for another task.
- Use only permitted, relevant evidence. An explicitly selected note may supply actions, order and exclusions; accurately explain which facts affected the answer. Do not infer emotional diagnoses from notes.
- The current stated need outranks unrelated saved work. A recovery request must not be acknowledged as a request to complete a saved task.
- Give a concrete action when the supplied facts support one. If the task or next step is unknown, ask one useful clarification. Do not substitute “complete an action cycle” for the missing understanding or invent details.
- Keep local deterministic provenance truthful. These repairs do not authorize a new external model, additional data sharing, billing changes or automatic persistence.

## Conversation and controls

- Retain natural saved-context declines across follow-ups; support English and Spanish wording.
- Treat corrections and completed-task statements as updates to the objective. Do not silently resurrect a completed or rejected task.
- A follow-up must receive the plan currently displayed, including user adjustments, with generated plan content distinguished from user-authored facts.
- Make smaller must produce one coherent instruction and current duration. Repeated taps must not accumulate earlier titles or durations.
- Different approach must address what is unsuitable about the method. It must not blindly increase the effort level.
- Editing planning context invalidates pending and displayed results. An obsolete answer cannot become current after an asynchronous completion.
- Retain the exact failed follow-up for retry. Avoid duplicate requests and clear retry state when its context is superseded.

## Presentation and speech

- Lead with a brief grounded acknowledgement and one executable next step. A useful question appears only when its answer changes the decision.
- Keep alternatives, rationale and evidence available without turning a brief follow-up into a report of every option.
- Full accessible output and short spoken summary serve different purposes. Summary must be shorter and describe the selected action and duration accurately.
- Localize affected controls and response framing. Spanish input and corrections need Spanish planning behavior, not only translated button labels.
- Preserve existing consent, crisis handling, speech cancellation and explicit Creator confirmation boundaries.

## Validation

Use the controller tests for evidence selection, safety, account scope and read-only behavior. Use `test/state/controllers/smart_planner_response_acceptance_test.dart` for independent audit and paraphrase cases, the response entity tests for serialization, and Smart Planner widget tests for state transitions and controls. Include related Creator handoff and assistant safety tests when validating the integrated change.

The behavioral cases check the actual objective, method, time cap and exclusions rather than exact prose or the mere presence of fields. A material contradiction fails its scenario even when every structural field exists. Optional response capture through `CHRONOSPARK_PLANNER_AUDIT_OUTPUT` supports review of complete host-generated input/output pairs.

Host results establish local behavior for the tested inputs. A rebuilt app must separately repeat the original Moto conversations and control interactions before claiming repaired device behavior. The build-3039 captures remain evidence of the earlier defects; they must not be relabeled as passes after a source repair.
