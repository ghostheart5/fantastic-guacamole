# Planner and SI conversation repair against shipped build 3059

## Status and scope

Local implementation; live model and rebuilt-device acceptance remain open. This is not a release-readiness certificate.

The user authorized connecting the existing AI service to Smart Planner and SI Console after reporting repeated generic responses, broken follow-ups and nonfunctional Advanced controls. Work is based on shipped build 3059 source commit `427d0d65f2bcb8693d6574ce84f52b40a03ab7a2`, in branch `codex/intelligence-response-repair-3059`, at `C:\src\cs-intelligence-3059-repair`. The earlier canonical checkout and the retained 3059 release worktree were preserved.

At the end of the initial local repair, no build, installation, commit, push, backend deployment, website publication or Google Play release had been performed. The user subsequently authorized committing, deploying and installing the repair. The delivery candidate is version `4.1.0+2026083060`; deployment and installation evidence must be recorded separately from the local results below. Google Play production publication remains excluded.

## Concrete failures and repairs

| User case | Confirmed cause | Local repair | Evidence boundary |
| --- | --- | --- | --- |
| “What time should I go to the store?” with Grocery list attached | Ordinary Planner requests use deterministic response construction, not the configured language model | Private AI conversation route carries the attached task, description, duration, recorded dates, explicitly selected note, current local time and both sides of recent conversation | Packet and screen tests pass; actual shopping advice from the live model remains untested |
| Follow-up repeats the same advice | The displayed answer was not a normal assistant turn in a model conversation; local why handling reused the answer | Both user and assistant messages accompany follow-ups; local why/smaller/done/rejected handling also repaired | Four new controller cases failed before the fixes; pass after |
| SI Advanced “tasks” cannot answer | Bare record names were not recognized as a listing request | English/Spanish bare task, goal and milestone listings recognized; explicit analysis mode takes precedence | Local engine tests pass |
| Entity filter/scenario stop working with the keyboard | Compact layout removed the Advanced subtree when the keyboard appeared | Advanced fields stay mounted; the new conversation also preserves them while editing | Phone-sized widget checks cover keyboard inset, retained text and mode selection |
| Changing query builder gives the same answer | Broad shared-decision shortcut could replace explicit analysis; scenario delay could remain the default | Explicit analysis avoids that shortcut, reads scenario delay; model packet carries mode, selected sources, range, title filter and scenario | Six-mode local checks and model-packet checks; live comparative answers remain open |

## Real conversation behavior

- Uses the existing authenticated `ai-proxy` service and its existing provider configuration. No second AI provider or new credential store was added.
- Enabled only through the existing eligible private credit-testing cohort. Public launch switches remain contained.
- External-AI consent, current account/session, release controls and emotion consent are rechecked before and after transport.
- Request disclosure precedes the backend quote. A separate confirmed credit price precedes model execution. Declining either confirmation does not execute a paid request.
- The immutable reviewed request and quote share a request ID. Retrying a failed transport preserves that ID, allowing the existing backend to prevent a duplicate debit.
- Context is bounded. Selected task comes first; omitted records and shortened conversation are disclosed to the model. Unavailable sources are identified. Filters bound the records sent.
- Conversation history contains up to six recent messages for model requests. The visible transcript belongs to the current screen session and is not a persistent conversation memory feature.
- Suggestions are read-only. They do not save, schedule or complete tasks. Existing on-device tools remain an explicit choice.
- Failure is displayed as failure. No local template is silently substituted as a model answer.
- Account changes dismiss request-review dialogs and clear conversation, pending quote, attached task, energy and Advanced selections. The unset energy selector no longer presents a fictitious 50% value.
- Both screens retain an explicit response-reporting action. Reporting discloses the selected response and account-linked storage before submission.
- Staged Planner entry requests prefill the new conversation for review rather than silently running the old response path.
- Updated canonical and generated privacy copies describe conversation processing. Those website changes are local and unpublished.

## Validation

Evidence is saved locally under `test-results/intelligence-3059-repair/`; the original user-supplied review flags are preserved there verbatim. Test transport responses are fixtures, not live model responses.

The targeted Flutter regression set covers conversation transport, disclosure and credit confirmation, account isolation, task/note context, Advanced editing, local Planner follow-ups, SI analysis, legacy screen behavior and privacy/source contracts. The backend set exercises the actual request handler with simulated provider responses, including failed/cut-off response refunds and duplicate retries. Exact final results are recorded alongside the local logs.

| Check | Result | Meaning |
| --- | --- | --- |
| Targeted Flutter regression, 14 test files | 327 passed | Includes both actual screen entry routes and the existing Planner/SI regression coverage |
| Final conversation screen checks after dialog-disposal hardening | 7 passed | Rechecks both conversation surfaces and proves removing the screen closes its private request-review dialog; six checks overlap the regression set |
| AI proxy handler and server-policy checks | 14 passed | Simulated provider, real handler; does not establish live model quality |
| Generated legal copies | Match canonical sources | Source check only; no website publication |
| Final whole-project static analysis | One redundant test import, subsequently removed | No source errors or warnings; affected-file recheck reports no issues |
| Formatting and whitespace | Passed | 18 Dart files required no formatting changes; three backend files passed formatting checks |

The final static-analysis result and source hashes are retained with the local evidence. Tests added during the repair exposed real failures before their corresponding source fixes; a root-entry fixture also required a synthetic evidence-source override instead of accessing an unconfigured database. That fixture failure was not classified as an app defect.

These checks do not establish live answer usefulness, on-device accessibility, installed-version correctness, actual cloud deployment or public release readiness. The old walkthrough evidence mostly showed screens; it did not prove that a question led to a useful answer. That evidence must not be reused as conversational acceptance.

## Required live acceptance before calling this repaired on the phone

1. Deploy the reviewed service policy and refund handling together with a fresh signed internal candidate and the corresponding privacy copy. Verify the actual installed version and eligible account. Do not publish production.
2. Attach a real Grocery list. Ask when to go without availability. Expect a focused question about missing timing, not invented store hours or a generic priority task.
3. Supply a 5–7 pm window and a 45-minute trip. Inspect whether the proposal fits those stated limits. Then move availability to 6 pm; the answer must adapt rather than repeat the previous window.
4. Ask why, ask for a smaller step, reject a step and say it is done. Check each against both sides of the conversation and the saved records. Suggestions must not claim a saved mutation.
5. In SI, submit “tasks” and “tareas.” Change answer to compare, explain, forecast, conflicts and counterfactual. Compare actual responses with the distinct questions, not merely whether any text rendered.
6. Change title filter, selected sources and date range. Verify excluded records are absent from the reviewed request and unsupported exhaustive claims are absent from the answer. Enter a scenario with the keyboard open, submit, and compare its consequences with the original scenario.
7. Cancel disclosure and credit confirmation; test insufficient credits, unavailable provider and same-request retry. Verify real balances and server settlement. Do not use real payment instruments.
8. Repeat the core interaction in Spanish. Check narrow-screen layout, large text and TalkBack on the device.
9. Inspect an unsafe or inaccurate answer report through its existing disclosure. Submit only if specifically authorized for the live reporting test.

## Known limitations and remaining original flags

- A completed model reply lost in transit is not recoverable through the existing proxy. Retrying does not charge twice, but returns a completed-request warning. A new request could cost credits again. Response replay is not implemented by this repair.
- Client-side response withholding occurs after the server may have settled credits. The backend refunds its own provider failures and blocked/cut-off replies; a new server-side refund/replay contract would be needed to guarantee zero charge for every client rejection.
- No live model answer was generated or graded during this implementation. No claim of “human” comprehension, guaranteed correctness or complete grounding is made from tests with fixtures.
- Voice controls, Creator execution and durable learning remain in the existing on-device tools; the new conversation does not silently execute those actions.
- Original flags 004 (Creator navigation), 005 (save receipt), 007 (cloud backup), 008 (Support back navigation), 011 (Momentum) and 014 (learning display) are outside this conversation repair and remain open. Flag 006 retains its user correction/reclassification; do not reassert a broken goal control based only on an automation hierarchy.
- Flags 001–003 have changes in the new conversation route, not a blanket closure of every legacy surface. Flags 009, 010, 012 and 013 have local repairs and regression evidence; final closure requires the live acceptance above.

## Delivery gate follow-up

The initial full cloud run found six failures missed by the targeted suite: domain classification, the public SI import boundary, the Planner support-file size, two privacy-copy contracts, and an older SI assertion that reused an unconstrained Home recommendation for a five-minute query. The fixes classify the new shipping entity, use the public SI facade, extract follow-up handling into a separately size-checked part, preserve explicit consent wording, and test both constrained and broad next-step questions. All 34 checks across the eight affected contract/conversation test files passed locally. Full cloud CI and device acceptance remain separate gates.

The delivery review then identified two further defects: optional task-detail loading could defeat partial-source degradation, and SI packets could include emotional state disclosed only for Planner. Four new regression cases reproduced both defects before correction. The factory now reads task details only for selected task evidence, marks failed enrichment explicitly while retaining the snapshot, rechecks the account boundary after that read, and includes emotional state only for Planner. The conversation, public-boundary and legal regression set passed all 31 tests. The previously green full run (35167049425: 3,277 unit/widget checks, 8 Linux integration checks, 64 Windows screen checks and 17 runner checks) applies to the preceding source; the final commit must pass fresh exact-source CI. Candidate build 35167959812 was canceled before delivery.

Before uploading the first successful 3060 artifact, the Moto pre-update check exposed obsolete billing copy stating that SI guidance always remains local. Settings, the paywall and the fictional credit-test panel now distinguish consented Planner/SI conversations from on-device tools and the separate synthetic credit test. The changed disclosures include Spanish copy. The successful artifact from run 35170254035 was not uploaded or installed; final delivery requires a newly verified artifact containing this copy repair. The phone baseline is Android review user 11, Dom, level 1, 75 XP, 3 completed tasks and 797 credits.

## September 17 follow-up repairs after live 3060 validation

The final 3060 build was delivered to the existing internal track and installed through Google Play. Five real SI requests exercised task filtering, conversational constraints, correction of an infeasible timing recommendation, an Advanced counterfactual and a Spanish follow-up. The 57 quoted credits matched server settlement and the observed balance change. This is scoped SI device evidence, not full Planner or whole-app acceptance; details remain in the ignored delivery report.

The user requested repairs to the remaining findings:

- The shared response body now renders selectable Markdown, including bold text, lists and horizontally scrolling tables with a visible scrollbar. SelectionArea preserves selection without the nested editable text widgets swallowing table drag gestures. User-entered text and original report payloads remain unchanged. Markdown images are rendered as labels without fetching network/local resources; links have no navigation callback. The formatter dependency is pinned and its existing dependencies were not upgraded.
- Planner defaults an explicitly attached task to an attached-task-only packet. Unrelated tasks, goals, milestones, timeline, selected notes and emotional state are excluded; explicitly supplied request energy remains available. An English/Spanish switch allows the user to choose broader context for review. Changing the task or scope clears conversation history and any pending quote, preventing earlier broader context from leaking into the narrowed request. The standard disclosure and credit confirmation still precede transport.
- The server-owned policy now distinguishes absence of a recorded deadline from absence of real-world urgency or consequences. It also limits claims about checking other commitments when only one task is provided. Prompt guidance cannot guarantee every future model response; this wording change still requires deployed live evaluation.

Validation: 32 focused Flutter checks passed across response rendering, actual screen transport, context exclusion/opt-in, consent, account boundaries and quote handling. The 14 backend policy/handler checks passed with simulated provider responses. Focused static analysis found no issues. A separate host-rendered preview using bundled Inter fonts was visually inspected. Tests cover 320/412-pixel widths at 2x text scale, horizontal table scrolling and disabled model-image loading. Two initial fixture errors (missing goal creation date and an incorrect assumption about Markdown span nesting) were corrected; they were not app defects.

These checks were completed before delivery of candidate 3061. Commit, build, deployment, Play track and installed-device evidence are recorded separately in the delivery receipt. Planner's task-only live acceptance requires the new installed build and does not require sharing unrelated personal goals.
