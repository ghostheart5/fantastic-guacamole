---
description: Use when changing billing, premium gating, or subscription storage.
---

Premium access must be derived from server-verified subscription state stored in secure storage. Do not trust SharedPreferences, local plan enums, or cached booleans as the source of truth for entitlement.

Receipt verification must fail closed when the verifier endpoint is missing, misconfigured, or returns an invalid response. If a purchase cannot be verified, do not grant premium access locally.
