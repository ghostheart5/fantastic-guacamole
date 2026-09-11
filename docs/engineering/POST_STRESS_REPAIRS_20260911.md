# Follow-up repairs for internal candidate 3029

The 3028 stress report remains a historical record of the published and installed build. These changes address its three new findings; they do not change billing prices, entitlements, consent defaults, or production availability.

- **S9, paywall scroll:** retain the plan list position across temporary authority-loading screens using route page storage. The loading gate still prevents interaction until verification returns. A widget test scrolls the catalog, holds a refresh pending, then verifies the original offset after data returns.
- **S10, support email:** encode mail query fields using URI component escaping before launching the email app. Spaces, Unicode, newlines, ampersands and literal plus signs survive correctly. This also covers the existing account-deletion support mail path; no mail is sent by the app or tests.
- **S11, SI context disclosure:** the ready banner now describes available user-reported context, without claiming every answer cited it. Query relevance recognizes explicit minute/hour wording, so a question about five minutes does not silently exclude consented capacity. Existing consent, freshness, account and unrelated-query exclusions remain in force. The ambiguous ranking observation is retained: explicit grocery wording already selects the grocery task; no speculative ranking weight change was made.

Focused local regression: 51 tests passed, zero failures/errors/skips (paywall, external URL launching, SI read gateway, SI screen). Final source CI, database, Maestro/Monkey, candidate build, native/Windows/16 KB and installed 3029 checks are still pending. Production publication remains prohibited.
