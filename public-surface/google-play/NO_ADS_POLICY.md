# ChronoSpark: no ads, ever

Owner requirement confirmed September 10, 2026: ChronoSpark will never show advertisements. No user will ever need to watch an advertisement.

This applies to every account, plan, build and distribution track. Do not add banner, interstitial, native, rewarded or app-open advertising. Watching ads must never unlock access, credits, tokens, XP, features or continued use. A depleted credit balance must lead to an honest balance/availability explanation and the separately approved purchase or allowance options, never an advertising offer.

Subscriptions and credit purchases, where enabled and disclosed, are separate from this promise. There is no paid ad-removal tier because there are no ads to remove.

Release checks must verify the Play Ads declaration says no, no ad-serving integration is reachable, and advertising-ID permissions remain removed from the merged artifact. Do not treat a dependency name alone as evidence that ads are displayed: build 2026083025 contains a transitive Google ads-identifier library through its Firebase dependency graph, while manifest advertising-ID permissions and analytics collection are disabled. Track that dependency honestly; do not claim that the archive contains no advertising-related library at all.

The candidate manifest verifier in `scripts/android_candidate_build.py` rejects advertising-ID, attribution, topics and custom-audience permissions in both ordinary and internal-billing profiles, including SDK-23 permission declarations. Its adversarial tests exercise all five forbidden permissions in both profiles and both declaration forms. This is one release safeguard; the separate source/integration review must still check that no ad-serving behavior is reachable.

The full listing and About copy should communicate the promise plainly. Future monetization changes must preserve it.
