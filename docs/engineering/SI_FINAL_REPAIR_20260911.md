# SI device findings repair — candidate 3030

The installed 3029 validation exposed a false date-based goal-ranking explanation, duplicate sentence punctuation and unsupported natural-language listing. A later explicit question could also retain irrelevant planning context from previous turns.

- Goal comparison now identifies title relevance when that determines ordering, dates only when relevance ties, and an explicit tie when both signals match.
- Exact bounded listing phrases for goals, tasks and milestones return saved titles from the current lens, at most 20 per answer, with the matched count and a narrowing instruction. Shared Home recommendations do not replace a requested listing's recommendation.
- Fresh explicit questions use their own wording for planning evidence and title relevance. Recognized short referential follow-ups retain recent wording. Safety/crisis screening still receives the entire recent conversation, so this is not a safety-context reset.
- User-authored context retains its original punctuation without an extra period.

Local validation: 34 focused cases passed with no failures or skips, including six new device regressions, the existing engine suite, consent/account evidence gateway checks and safety-service cases. The first run caught an over-specific empty-list assertion; the existing honest empty-evidence response was preserved. A static style finding was fixed. Exact-source hosted checks, signing and installed-3030 acceptance remain pending. Both Android and Flutter version declarations are 2026083030.

Public paid features remain gated. No review approval was invented, and no production publication occurred. This repair does not close independent store, reviewer, operational or qualified-review requirements.
