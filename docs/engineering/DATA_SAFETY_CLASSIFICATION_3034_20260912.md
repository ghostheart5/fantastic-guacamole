# Data safety reporting classification - build 3034

Date: September 12, 2026. Scope: SI response reporting and enabled external planning payloads. Status: classification correction saved as a Google Play Console draft; no review submission or production publication. Final independent readback is recorded below.

## Candidate and backend identity

- Source: `edb5001600ad3fd20f1fdc1e470b0fd293c5ef7a`, version `4.1.0+2026083034`, Play internal release 35.
- Signed AAB SHA-256: `01536d667f204c64cf56f47328052ac6a8b018562687cba4c1f9d883b6addd73`.
- Canonical Supabase project: `qpwhuckyirnqtmvhpede`. Read-only live inspection found `ai-report` ACTIVE, version 6, JWT verification enabled. Its retrieved source matches the candidate function after line-ending/final-newline normalization. Retrieved source-bundle SHA-256: `07478ce88bde591149a44c4894f170e8180c533a58826e3de28782f90d6f6fac`.
- Receipts: `test-results/data-safety-3034/backend-readback.json` and `deployed-ai-report.ts`. Historical memory that this function was local-only is superseded by this live inspection.

## Actual report flow

`si_console_screen.dart` submits the selected message text after the user chooses a reason and confirms Send report. `ai_content_report_service.dart` trims the response, limits it to 4,000 characters, and posts JSON fields `reason` and `content` over HTTPS with the account access token in the Authorization header. It does not separately attach the original prompt, conversation-history array, diagnostics or planning database.

The selected text can nevertheless repeat user content. `SIV2Response.toPlainText()` includes observed facts, user-reported context, recommendations and evidence labels/links. A report can therefore contain task names, goal or note details, or other user-written information present in that response. Classifying this solely as App interactions would omit actual content.

The deployed function authenticates the user, validates the reason and content, then stores `user_id`, `reason`, `content` and `source=si_console` in `ai_content_reports`. The live table also has `id`, `status` and `created_at`. It returns an accepted response after storage. There is no Anthropic forwarding in this reporting function.

The live foreign key is `user_id REFERENCES auth.users(id) ON DELETE CASCADE`. This establishes report-row deletion when the corresponding auth user is deleted; it is not a new end-to-end account-deletion test. A bounded cron query found no command directly naming this report table. No automatic purge duration is asserted, and backups or indirect automation were not exhaustively inspected. Stored reports are not ephemeral.

## Category correction

Google defines chat content under Other in-app messages and miscellaneous user-written content such as notes under Other user-generated content. Collection includes transmission off the device. Service-provider processing can be exempt from the separate sharing declaration while still being collection. Reference: [Google Play Data safety definitions and purposes](https://support.google.com/googleplay/android-developer/answer/10787469).

| Added type | Content represented | Collected | Shared for this flow | Optional | Ephemeral | Purposes |
| --- | --- | --- | --- | --- | --- | --- |
| Other in-app messages | Selected SI reply submitted for review | Yes | No | Yes | No | App functionality; Fraud prevention, security, and compliance |
| Other user-generated content | User-written planning details repeated in that reply | Yes | No | Yes | No | App functionality; Fraud prevention, security, and compliance |

Reporting is optional: users may use ordinary local planning without submitting a report. The purposes cover the reporting feature and safety/privacy review. No advertising, marketing, personalization or analytics purpose was added. The sharing answer for this reporting flow rests on first-party report handling and service-provider hosting; it does not certify all unrelated SDK/provider flows.

The eight existing categories and their answers were preserved: Name, Email address, User IDs, Purchase history, Photos, Voice or sound recordings, App interactions, Device or other IDs. The corrected draft has ten collected types. Transit encryption, account creation methods, privacy URL and account-deletion URL were preserved. The separate partial-data-deletion answer remains No; Google's additional partial-deletion wording does not negate the account-deletion link.

## External planning distinction

Candidate `LaunchContainment.externalAiSafetyReviewApproved` is false. `planner_explanation_provider.dart` checks this gate before constructing the HTTP service and otherwise returns a disabled port. The signed assistant policy additionally rolls back `plannerExplanation`. Ordinary SI and Planner content is therefore not forwarded through that explanation control in build 3034.

The eligible internal credit test is separate. `internal_credit_test_provider.dart` uses fixed fictional tool-shelf/gardening prompts with empty history and context, under its consent and eligibility checks. It does not attach the user's planning library. Authentication, purchase and credit-usage metadata remain relevant to the existing declarations. Enabling personalized external planning later requires another payload/category review; this checkpoint does not approve enabling it.

## Wording clarification implemented locally - not published or installed

The owner's subsequent Continue instruction authorized applying the prepared clarification. Both English and Spanish report dialogs now disclose repeated planning content, account linkage and report storage. The service documentation no longer promises that selected response text can never contain prompt/history details. The canonical privacy page includes the reporting paragraph below and a September 12 policy date; the existing generator synchronized the three privacy derivatives. No transport behavior changed. This source delta is newer than installed build 3034 and is not part of its prior device evidence.

Suggested report-dialog wording:

> Send this selected response and your reason to ChronoSpark for safety review. The response may contain details from your tasks, goals, notes or conversation. We do not attach the rest of your conversation. The report is linked to your account and stored for review.

Suggested explicit privacy paragraph:

> If you choose to report an SI response, we receive the selected response, your reporting reason and your account identifier. The selected response may include planning or other personal details that appear in it. We store the report to review safety, privacy and accuracy concerns; it is not processed only in memory. The reporting service does not forward the report to our external AI provider. Report records are linked to your account and are deleted from the report table when your account is deleted. The general retention and deletion terms in this policy also apply.

These words are now in local sources, not the installed app or public policy. The public policy remains at the previously verified PR 103 / build 3034 version. Local privacy sources intentionally differ by this new reporting section and date; do not reuse the old parity receipt to claim this newer wording is live. Rebuilding the app and publishing the coordinated policy update remain delivery steps before public-release sign-off.

## Validation and limits

Live function/source and schema readback were read-only. No user report rows were inspected, no real report was submitted, no backend mutation was performed and no private content was sent to a reviewer. This is source/configuration and declaration evidence, not a fresh report end-to-end runtime test. The initial declaration correction did not change application source. The subsequent local wording repair does; its targeted Flutter validation is recorded in `test-results/data-safety-3034/disclosure-repair-validation.md`.

The Console displayed `Change saved. Send for review in Publishing overview.` after Save as draft. Leaving the form and reopening it independently retained Messages 1/3 and App activity 2/5. The handling/preview readback is recorded in `test-results/data-safety-3034/console-readback.json`.

The report-content category gap is closed in the saved draft, and the wording clarification is implemented in local source. Coordinated app/policy delivery, final disclosure review and any qualified external reviews remain separate. No Data safety review submission, production-access application or Google Play production publication occurred.
