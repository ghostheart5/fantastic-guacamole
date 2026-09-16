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

Candidate 3016 source `10b63ffabf179893ca66ecd33811062885713cf0` passed [CI 34179863899](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34179863899): 2,564 unit/widget tests, 15 configuration tests, 38 Windows checks, 16 launcher checks, and 8 Linux integration tests, all with zero failures/errors/skips. [Backend 34178361523](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34178361523) passed 96 Edge Function tests on unchanged backend source. [Signed build 34180727836](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34180727836) completed successfully, but was inspected in memory for its compiled endpoint but not retained, published, or installed because the credit-test UI gap was found. These results do not prove the new panel's live behavior.

## Play and device checkpoint

The monthly `monthly-prepaid-test` base plan was saved as Draft in Play Console: one month prepaid, USD 4.99, United States only. Activate only after the corrected build is installed. Chrome control failed; Edge opened the same authorized Play Console account successfully. Existing internal release draft 19 is available for the final candidate.

Moto remains on 3014, owner profile level 2, with its saved data preserved. Owner server wallet was 20 free credits and the prior subscription expired at the last readback. Second account had no wallet or entitlement row. No live prepaid payment or AI credit-spending pass is claimed yet. Remaining device acceptance is listed in the 3016 report and applies to this final candidate. Monkey and level-20 testing are explicitly excluded.

## Completed 3017 execution and follow-up findings

Source `5310f8e817855700e2d9cb9d152abafcb73c819f` passed CI 34182118968: 2,573 unit/widget, 15 configuration, 38 Windows, 16 launcher, and 8 Linux integration tests; zero failures/errors/skips in those reports. Maestro 34182120391 attempt 2 passed all 11 journeys. Attempt 1 was blocked by a Pixel Launcher ANR dialog over the welcome screen; its failure screenshot and manifest are preserved.

Signed build 34182987588 attempt 2 passed. Attempt 1 stopped before compilation because the RTDN test was older than 24 hours; a fresh Console test processed at 2026-09-08T03:23:13Z. Verified AAB SHA256: `fd9f883b85f670a185e07d5d5c7bcb01539f2005e78d9a3d1623fba2cf64f849`. Package, version, signer, compiled AI endpoint, and internal credit panel were checked locally. Internal release 19 became available to testers, and Moto updated through Google Play to 3017, preserving the owner level-2 profile.

Live synthetic credit tests passed: consent-off controls disabled; one- and two-credit debits; same-request replay with no second charge; insufficient balance at one credit and zero. Eleven completed requests used exactly 20 credits; two rejected requests made no debit. A rollback-isolated invocation of deployed reserve/settle routines verified refund and duplicate-refund accounting, with zero retained test rows. This is database evidence, not an induced upstream outage. Consent was restored to off.

Prepaid slow-decline and slow-approve instruments appeared in Google's no-charge test checkout. Pending access remained unchanged; restart and Restore granted nothing for the declining purchase. Its type-20 notification failed because Google already returned EXPIRED. A diagnostic deployment confirmed that safe state, then RTDN v16 repaired standalone/delayed terminal handling; Google retried the original notification successfully at 03:58:44Z. The approval case activated at approximately 03:59:13Z and expired at 04:04:13Z. During active access, the second account received no entitlement from Restore; returning owner restored active access and retained level 2. Both account switches entered Nexus directly, and system Back from Settings worked.

New failures prevent an all-pass claim: Settings retained obsolete credit-unavailable copy; toggle labels were separate from unnamed switch controls; completed prepaid access did not fill its 300-credit allowance. These are being repaired in candidate 3018. Second-account live spending, final corrected-build device acceptance, and broader remaining journeys are still pending. Monkey and level-20 tests remain excluded.
