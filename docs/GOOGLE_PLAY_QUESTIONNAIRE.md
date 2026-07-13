# ChronoSpark Google Play Closed-Testing Questionnaire

> Pre-drafted answers for the Google Play review questionnaire.  
> Fill in bracketed placeholders as real data becomes available.

---

## 1. How did you recruit testers?

Testers were recruited through direct invitation via the Google Play closed testing track. Invitation links were shared privately with known individuals — colleagues, friends, and domain-relevant users — who agreed to provide structured feedback. No public advertising was used for this closed test cycle.

**Evidence to collect:**
- [ ] Screenshot or export of the Play Console tester list
- [ ] Date invitations were sent

---

## 2. How many testers participated?

**[Fill in when data is available]**  
Target: ≥5 testers for initial closed test cycle.  
Actual: `[X]` testers installed the app as of `[date]`.

**Evidence to collect:**
- [ ] Play Console → Internal testing → Tester count screenshot

---

## 3. What feedback did testers give?

**[Fill in as feedback arrives — draft structure below]**

| Theme | Count | Notes |
|-------|-------|-------|
| Login / auth issues | [X] | |
| UI clarity | [X] | |
| Performance | [X] | |
| Missing features | [X] | |
| Crash reports | [X] | |

Summary statement (draft):

> Testers reported [X] issues. The most common themes were [A], [B], and [C]. Feedback was collected via email to ghostheart131517@gmail.com and through crash reports in Firebase Crashlytics.

**Evidence to collect:**
- [ ] Email thread or summary of tester feedback
- [ ] Crashlytics dashboard screenshot

---

## 4. What issues did you fix based on tester feedback?

**[Fill in per issue fixed]**

| Issue | Severity | Fix Description | Commit / Version |
|-------|----------|-----------------|-----------------|
| [description] | [High/Med/Low] | [what was changed] | [SHA or v1.x] |

**Evidence to collect:**
- [ ] GitHub issue links or changelog entries

---

## 5. How does your app handle user data?

ChronoSpark processes the following categories of data:

**Collected and stored locally on-device:**
- Task, goal, habit, and focus session data created by the user
- Productivity metrics (streaks, XP, momentum, energy)
- User preferences and app settings
- AI conversation history (local memory layer)

**Transmitted to external services (when enabled by build config):**
- Account email address and display name — sent to Supabase for authentication
- Anonymous usage events — sent to Firebase Analytics
- Crash diagnostics and device metadata — sent to Firebase Crashlytics
- Conversational prompts — forwarded through a secured AI proxy to an upstream AI provider; no raw content is stored beyond what is needed to generate a response
- Purchase receipt tokens — sent to a server-side receipt verification endpoint; not stored on third-party advertising systems

**Not collected:**
- Precise location
- Contacts or calendar data
- Financial information beyond purchase receipt tokens
- Photos, camera, or microphone input (unless user explicitly activates voice features)

**Retention and deletion:**
- Local data is retained until the user clears it, resets the app, or uninstalls
- External provider retention follows each provider's policy
- Account and external data deletion can be requested at `https://ghostheart5.github.io/fantastic-guacamole/delete-account/`

---

## 6. How does your app comply with Google Play policies?

| Policy Area | Compliance Statement |
|-------------|---------------------|
| Data Safety | Data Safety section completed in Play Console; categories match §5 above |
| Privacy Policy | Hosted at `https://ghostheart5.github.io/fantastic-guacamole/privacy/` |
| Account Deletion | Self-service deletion page linked from app settings and hosted at `/delete-account/` |
| Permissions | Only `INTERNET`, `BILLING`, `RECEIVE_BOOT_COMPLETED`, and `POST_NOTIFICATIONS` are requested; each is required for a disclosed feature |
| In-App Purchases | Products use Google Play Billing; pricing displayed before purchase; no dark patterns |
| Children's Audience | App is **not** directed at children under 13; no child-directed content |
| Sensitive Permissions | Microphone permission requested only when user activates voice input (optional feature) |
| Spam / Misleading Behaviour | App does not use fake reviews, misleading descriptions, or deceptive subscriptions |

**Evidence to collect:**
- [ ] Screenshot of completed Data Safety section in Play Console
- [ ] Screenshot of privacy policy URL set in Play Console
- [ ] Screenshot of delete account link visible in app settings
- [ ] Permissions manifest extract from final AAB

---

## Living Evidence Log

Update this table as testing progresses:

| Date | Item | Link / Attachment |
|------|------|------------------|
| | Tester count screenshot | |
| | Crashlytics dashboard | |
| | Feedback summary | |
| | Issues fixed changelog | |
| | Data Safety screenshot | |
| | Permissions manifest | |
