# Planner follow-up repair for internal billing build 3010

Build 3009 device testing found that declining the saved-work clarification
repeated the question, and a subsequent desk-organizing request could be
replaced by a generic saved recommendation.

The controller now recognizes a declined saved-work choice for the current
conversation, preserves consented capacity limits, and allows an explicit
request to opt back into saved work. Concrete follow-ups use their own target;
references such as "make that more specific" retain the previous target.
Conversation history remains available to the safety checks. Recommendation
matching uses the recommended action rather than explanatory boilerplate.
The request remains read-only; saving still requires Creator confirmation.

The public-site deployment contract now requires the canonical September 7
Terms disclosure: eligible license testers use uncharged Google test payment
methods, internal-track enrollment alone does not make purchases free, and
AI-credit purchases and spending remain unavailable.

Local validation: 64 related controller, screen, input-lifecycle, and
Planner-to-Creator persistence tests passed, followed by an additional
capacity/opt-back-in regression. Generated legal copies matched their sources.
Exact-commit CI, signed-build verification, public-page readback, and Moto
runtime evidence are separate release gates; these local results do not
establish their completion or authorize a level-20 pass claim.
