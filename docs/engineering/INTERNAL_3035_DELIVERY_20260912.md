# Internal build 3035 and matching privacy delivery

September 12, 2026. Status: coordinated policy and internal-app delivery complete; scoped Moto validation passed. Ready for continued authorized internal testing. Google Play production publication is excluded.

## Committed source and validation

- App repair commit `8b7105edad48dbdee6bf8cf97ba7eff3ac6a2675`; Android version alignment `3a2118ac2a4e523d1df962ee7290085d5e7ca310`. Both pushed to `fix/aab-prebuild-cleanup-20260905`.
- Exact signed-build source: `3a2118ac2a4e523d1df962ee7290085d5e7ca310`, version `4.1.0+2026083035`, package `com.ghostheart5.chronospark`.
- Targeted source validation: 25 legal/SI Console tests passed after updating the old Spanish disclosure assertion. Generated policy copies and formatting passed.
- First CI `34723911676` caught Android's version property still at 3034 while pubspec was 3035; the candidate was not signed. Corrected the property, passed the local version guard, committed and reran exact-source CI.
- Corrected CI [34724066811](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34724066811): SUCCESS. Independently downloaded manifests confirm 2,946 Flutter tests and 15 QA configuration tests passed, zero failures/errors/skips. Linux app-root integration, Windows golden comparisons, static policy and aggregate jobs passed.
- Signed build [34724793839](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34724793839): SUCCESS. AAB SHA-256 `0c527ab4b1ebff2fb636b3678f48b079e0e735dd53e0383ab170f7cf37248fb7`. Independent verification passed for exact source/CI/version, signature, pinned upload certificate, internal billing/no-ads containment and eight native 64-bit library alignments. The declared bundled privacy text matches the coordinated source byte for byte. The initial added verifier incorrectly expected an HTML privacy asset that pubspec does not bundle; it was corrected to check the actual declared text asset and then passed.

## Published privacy update

[PR 104](https://github.com/ghostheart5/fantastic-guacamole/pull/104) merged at 23:09:20 UTC as `98094876498363be8546c493c35193c000dca389`. The merge contains only the four approved privacy files. Normal branch protection remained enabled. Its automated review identified the old main-branch report dialog; the coordinated app repair already includes the corrected English/Spanish account and content disclosure. The thread was resolved on that evidence without administrator override. Main serves the website; the shipping app source is explicitly identified above.

Pages [34724660852](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34724660852) succeeded. Fresh HTTPS GETs for privacy, terms, support and account deletion returned 200 and matched the app candidate sources byte for byte. The new reporting section is live at https://chronospark.app/privacy/. Privacy SHA-256: `5818c96342b58562b2816068df151e20e0445e74def8f91e4c21ba2b65354ac0`.

The ten-category Data safety correction remains saved as a Console draft; this delivery does not submit the broader store declarations or listing changes for review.

## Artifact, internal rollout and installed-device evidence

Google Play internal release 36, `2026083035 (4.1.0) - Report privacy clarity`, was published and independently read back as Available to internal testers, released Sep 12 at 6:31 PM. Preview had no blocking error or supported-device count change; mapping and native symbols were attached. No production rollout or broad Publishing overview submission was performed.

Moto `ZY22G665VG`, Android user 0, was updated through Google Play from 2026083034 to 2026083035. Independent package readback: versionName 4.1.0, versionCode 2026083035, target SDK 36, installer `com.android.vending`, lastUpdateTime `2026-09-12 18:37:52`. The store initially retained older metadata; clearing Google Play Store's temporary cache exposed Update and the new release notes. Neither ChronoSpark storage nor Play Store user data was cleared, and no app was uninstalled.

The app opened at Nexus with level 20 and the saved bookkeeping task preserved. SI displayed 3 tasks, 7 goals, 0 milestones and 1463 Timeline entries. A read-only next-action query returned the saved bookkeeping recommendation. The report dialog displayed the complete revised English disclosure; screenshot inspection confirmed readable text and visible Reason, Cancel and Send report controls. Cancel dismissed it without submitting a report. Spanish disclosure is covered by the passing automated dialog journey; it was not separately exercised on the physical device in this delivery.

Settings > Help & legal > Privacy Policy opened the current hosted policy through the configured GitHub Pages link, resolving to `chronospark.app/privacy/`. Native page content contained the September 12 date and the new reporting/account-identifier paragraph. The AAB's declared offline privacy text also matched source exactly. Final phone screen: Nexus, level 20, saved bookkeeping task visible, no active speech or recording initiated by this check.

The captured current app-process log had no matches for FATAL EXCEPTION, Unhandled Exception, RenderFlex overflow or E/flutter. This is a bounded log check, not a guarantee of no possible errors. No purchase, credit spending, report transmission, task completion, level progression, monkey test or full native endurance test was performed in this scoped delivery. Other production gates remain outside this update.

Receipts are retained under `test-results/release-3035/`, including the failed first static check, corrected CI manifests, exact policy identity, merge/deployment receipts and live HTTPS readback. Local and hosted checks do not imply Google production approval or completion of unrelated external review gates.
