# Internal 3012 subscription navigation repair

On Play-delivered 3011, Android Back from the subscription page returned to
Google Play instead of Settings. Both Settings entry points replaced the
router stack when opening the paywall. They now push the destination so the
Settings screen is retained and Android Back returns there, matching the
paywall header's Back action.

Two regression tests reproduced the missing return route for Manage plan and
View credits before the fix. After the fix, all 32 Settings and paywall tests
passed, including Android Back and preservation of active subscription display.
Version 4.1.0+2026083012 will require exact-source CI, signed artifact
verification, internal-track delivery, and a Moto retest.

Predecessor 3011 was installed through Google Play and retained the signed-in
profile, level 2, 125 XP, two-day streak, and active annual test subscription.
Restore returned active. Its repaired Planner respected a ten-minute request
and retained the desk subject and newer five-minute limit across two follow-ups.
These are predecessor observations, not proof of a completed 3012 release pass.
