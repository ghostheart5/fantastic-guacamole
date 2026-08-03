# GitHub Pages Audit - ChronoSpark

Date: 2026-08-01
Repo: fantastic-guacamole

## 1) Audit Summary

Current status:
- You already have a strong public marketing core (home, about, download, support, privacy, terms, tester hub).
- You also have app deep-link landing pages under /app/* for indexing.
- There are multiple duplicate legal/support/privacy routes across root, /web, /docs, and /assets/legal that can create SEO and maintenance drift.

Primary recommendation:
- Pick one canonical GitHub Pages route structure and keep only one maintained source for each page.
- Keep app-route pages lightweight for deep links, but move full human-facing content to canonical marketing/legal pages.

## 2) What Exists Today (Observed)

### Core marketing pages (root)
- /index.html
- /about.html
- /download.html
- /support.html
- /contact.html
- /testers.html
- /CHRONOSPARK.html

### Legal pages (multiple copies)
- /privacy.html
- /terms.html
- /privacy-policy/index.html
- /privacy/index.html
- /terms/index.html
- /terms-of-service/index.html
- /docs/privacy-policy.html
- /docs/delete-account.html
- /assets/legal/*.html

### App-link pages
- /web/app/index.html
- /web/app/nexus/index.html
- /web/app/creator/index.html
- /web/app/logs/index.html
- /web/app/temporal/index.html
- /web/app/si/index.html
- /web/app/settings/index.html

### Additional web variants
- /web/index.html
- /web/privacy.html
- /web/privacy/index.html
- /web/support/index.html
- /web/terms/index.html

## 3) Key Issues To Fix

1. Duplicate routes for same content
- Privacy, terms, support, and legal content exist in several locations.
- Risk: inconsistent updates and conflicting indexing.

2. Mixed canonical domains and route styles
- Some pages reference ghostheart5.github.io/fantastic-guacamole.
- Some pages reference chronospark.app.
- Risk: split authority and crawler confusion if canonical tags are inconsistent.

3. Root pages vs /web pages overlap
- Both root and /web folders contain public pages.
- Risk: unclear deployment source of truth.

## 4) Recommended Canonical GitHub Pages Information Architecture

Use this as the final public website map.

### A. Marketing and product pages
1. Home (/)
- Hero value proposition
- Core product pillars
- CTA to download/waitlist
- Trust strip (platform, security, privacy)

2. Features (/features)
- Full feature matrix
- Core planner features
- SI/AI decision support
- Temporal Ops and Console positioning
- Offline/sync behavior overview

3. Pricing (/pricing)
- Base, Premium, Ultimate comparison
- Trial limits and premium unlocks
- Billing FAQ and restore purchases info

4. Download (/download)
- Current availability by platform
- Play testing status
- Install/tester instructions

5. Changelog (/changelog)
- User-facing release notes
- Bug-fix highlights
- Breaking changes and migration notes

6. About (/about)
- Product mission
- Design philosophy
- Build roadmap themes

### B. Support and trust pages
7. Support (/support)
- Support contact flow
- Response timelines
- Bug report checklist

8. FAQ (/faq)
- Account, sync, subscriptions, privacy, backups
- Testing vs production behavior explanation

9. Status (/status) (optional but recommended)
- Service component status (auth/sync/ai)
- Known incident notes

### C. Legal and compliance pages
10. Privacy Policy (/privacy)
- Data categories, purposes, retention, deletion, rights

11. Terms of Service (/terms)
- Usage terms, billing, liability, acceptable use

12. Security Policy (/security)
- Vulnerability disclosure channel
- Security practices summary

13. Delete Account (/delete-account)
- Exact steps, identity verification, deletion/retention timelines

### D. App deep-link/indexing pages
14. App Links index (/app)
- Link hub for deep links only

15. App route pages (/app/nexus, /app/creator, /app/logs, /app/temporal, /app/si, /app/settings)
- Minimal SEO/metadata + open-in-app action
- No duplicated long-form marketing text

## 5) Main Feature Content You Should Explicitly Cover

These are the main product features your public pages should communicate clearly:

1. Adaptive planning engine
- Dynamic task prioritization using workload, energy, and behavior patterns.

2. Time orchestration
- Temporal Ops for time blocking and timeline-oriented execution.

3. SI decision support
- Next-step recommendations, focus guidance, and system notes.

4. Nexus dashboard
- Central command surface for daily focus and momentum.

5. Creation workflow
- ChronoCreator for tasks, routines, and mission planning.

6. History and reflection
- ChronoLogs and progression views to learn from patterns.

7. Premium progression
- Clear Base/Premium/Ultimate boundaries and trial behavior.

8. Privacy-first trust posture
- Local-first behavior where applicable, cloud sync expectations, data controls.

## 6) Recommended Route Consolidation Plan

Step 1
- Choose one public source tree for GitHub Pages:
  - Option A: root pages as source of truth.
  - Option B: /web as source of truth.

Step 2
- Keep only one canonical URL per legal page:
  - /privacy
  - /terms
  - /support
  - /delete-account
  - /security

Step 3
- Redirect all alternates to canonical routes.

Step 4
- Standardize canonical tags and sitemap entries to one domain policy.

Step 5
- Keep /app/* pages minimal and stable for app links/indexing.

## 7) Prioritized Gaps (High -> Medium)

High
- Missing dedicated /features page.
- Missing dedicated /pricing page.
- Missing dedicated /faq page.
- Missing dedicated /delete-account page in canonical top-level route style.
- Missing dedicated /security page in canonical top-level route style.

Medium
- Missing /changelog page.
- Missing /status page.
- Missing sitemap/robots alignment checks for final canonical map.

## 8) Minimum Viable Final Page Set (Launch)

Recommended launch set:
- /
- /features
- /pricing
- /download
- /about
- /support
- /faq
- /privacy
- /terms
- /delete-account
- /security
- /changelog
- /app
- /app/nexus
- /app/creator
- /app/logs
- /app/temporal
- /app/si
- /app/settings

This gives you a complete public site for users, testers, legal compliance, and app indexing without route duplication.
