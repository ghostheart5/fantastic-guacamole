# Public Document Ownership

This document is the release-source map for ChronoSpark public pages. A source is authoritative only when it is marked **Published** below.

| Content | Authoritative source | Public route | Status | Review owner |
| --- | --- | --- | --- | --- |
| Privacy policy | `web/privacy/index.html` | `/privacy/` | Published | Product and privacy owner |
| Terms | `web/terms/index.html` | `/terms/` | Published | Product and legal owner |
| Account deletion | `web/delete-account/index.html` | `/delete-account/` | Published | Support and privacy owner |
| Support | `web/support/index.html` | `/support/` | Published | Support owner |
| Local legal reference files | `assets/legal/*` | None | Historical repository reference; not runtime or published source | Documentation owner |
| Legacy privacy copy | `docs/privacy-policy.html` | None | Historical, noindex | Documentation owner |
| GitHub Pages audit | `docs/GITHUB_PAGES_AUDIT.md` | None | Historical | Documentation owner |

## Release rule

1. Edit only the authoritative source for a public page.
2. Update its visible date when a substantive disclosure changes.
3. Keep historical copies noindex and visibly labelled; never publish them as a second route.
4. Before release, verify deployed routes, canonical tags, and the deletion-page link manually in a normal browser.

The `web/` folder is the public-site source. `docs/` is never a published legal source unless this table is deliberately amended.
