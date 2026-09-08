# Internal 3017 credit-test acceptance

## Change and evidence boundary

Version 4.1.0+2026083017 adds an explicit internal credit-test panel in Settings > Planning & guidance > Planning personalization. The current SI Console is local V2 guidance; enabling the legacy AI controller did not make spending reachable from that screen. Those unused legacy enablement changes were removed. No public external-AI launch is claimed.

The new panel is limited to the existing two-account internal billing cohort and requires per-account external-AI consent. It sends only a fixed fictional tool-shelf prompt, empty context, and empty history through the authenticated Supabase AI proxy. It exposes one-credit and two-credit requests, replay of the same request identity, and authoritative wallet refresh. It never writes a local production credit balance, grants premium, or changes XP. Unknown/time-out responses are described as unconfirmed rather than free or successful. An account switch discards the old account's result and replay identity.

## Local validation

- Nine focused controller/widget tests pass: hidden controls outside the cohort, consent-off protection, synthetic-only request content, two request costs, replay identity, duplicate-tap protection, account-switch isolation, insufficient/uncertain failures, and response identity validation.
- The visible two-credit action updates its server-wallet fixture at 320dp width and 200% text without layout exceptions.
- Targeted analysis reports no issues. Architecture and release/version guards pass.
- The combined Settings, credit-panel, credit-gate, and billing-offer regression run passed all 39 tests. The secret content guard and whitespace checks passed. Full exact-source hosted checks remain pending at this checkpoint.

## Previous candidate evidence

Candidate 3016 source `10b63ffabf179893ca66ecd33811062885713cf0` passed [CI 34179863899](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34179863899): 2,564 unit/widget tests, 15 configuration tests, 38 Windows checks, 16 launcher checks, and 8 Linux integration tests, all with zero failures/errors/skips. [Backend 34178361523](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34178361523) passed 96 Edge Function tests on unchanged backend source. [Signed build 34180727836](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34180727836) completed successfully, but was not downloaded/published/installed because the credit-test UI gap was found. These results do not prove the new panel's live behavior.

## Play and device checkpoint

The monthly `monthly-prepaid-test` base plan was saved as Draft in Play Console: one month prepaid, USD 4.99, United States only. Activate only after the corrected build is installed. Chrome control failed; Edge opened the same authorized Play Console account successfully. Existing internal release draft 19 is available for the final candidate.

Moto remains on 3014, owner profile level 2, with its saved data preserved. Owner server wallet was 20 free credits and the prior subscription expired at the last readback. Second account had no wallet or entitlement row. No live prepaid payment or AI credit-spending pass is claimed yet. Remaining device acceptance is listed in the 3016 report and applies to this final candidate. Monkey and level-20 testing are explicitly excluded.
