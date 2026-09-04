# Public Document Ownership

`legal/legal_documents.json` is the single machine-readable ownership and
generation manifest for ChronoSpark legal and support documents. A document
body is authoritative only at the manifest's `source` path and when it is
marked **Published** below. Every bundled or compatibility path is generated;
never edit a generated copy directly.

| Content | Authoritative source | Public route | Status | Review owner |
| --- | --- | --- | --- | --- |
| Privacy policy | `web/privacy/index.html` | `/privacy/` | Published | Product and privacy owner |
| Terms | `web/terms/index.html` | `/terms/` | Published | Product and legal owner |
| Account deletion | `web/delete-account/index.html` | `/delete-account/` | Published | Support and privacy owner |
| Support | `web/support/index.html` | `/support/` | Published | Support owner |
| Bundled offline copies | Generated from the four manifest sources into `assets/legal/*` | In-app fallback | Generated, not authoritative | Build system |
| Legacy privacy copy | `docs/privacy-policy.html` | None | Historical, noindex | Documentation owner |
| GitHub Pages audit | `docs/GITHUB_PAGES_AUDIT.md` | None | Historical | Documentation owner |

## Release rule

1. Edit only the authoritative source for a public page.
2. Update its visible date when a substantive disclosure changes.
3. Run `dart run scripts/generate_legal_copies.dart`, then require
   `dart run scripts/generate_legal_copies.dart --check` to pass.
4. Keep historical copies noindex and visibly labelled; never publish them as
   a second route.
5. Before release, verify deployed routes, canonical tags, and the
   deletion-page link manually in a normal browser.

The `web/` paths listed in the manifest are the public-site body sources.
`assets/legal/`, root compatibility routes, and `docs/` are never published
legal sources unless both the manifest and this table are deliberately amended.
