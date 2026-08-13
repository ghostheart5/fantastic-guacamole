# BASELINE-BUILD-03 Responsive Source Restore

## Purpose

This repair restores the omitted responsive-layout source that committed Nexus
and Timeline consumers already import. It restores the Phase 2 verified source
without redesigning its API or changing any consumer.

## Provenance

- Consumer-import commit: `343c83d029eb530a457d370e0bcf27b3b9048476`
- Phase 2 recovery archive entry:
  `tree\\lib\\ui\\layout\\responsive_layout.dart`
- Recovery archive:
  `ChronoSparkRecovery\\phase2-20260812-164222\\chronospark-dirty-tree-20260812-164222.zip`
- Verified SHA-256:
  `510265F59ECC336DE706C22C89F222DCABE73236CD1FF43E0BC59FFE09C92F0F`
- Verified Git blob: `51047c12c3bda6a167003f5da5cf9a9b5f54acab`
- Source size: 1,783 bytes

The recovered source is byte-identical to the protected primary-worktree
version and is classified as recoverable authoritative source.

## Restored Contract

`AppViewport` provides the established 600, 840, and 1200 width breakpoints;
compact-height detection; page padding; and responsive maximum content widths.
`ResponsiveContent` preserves the established aligned, constrained responsive
content-column behavior.

Focused widget tests lock the existing boundary, padding, width, and alignment
behavior. The sandbox `.env` used only for Flutter validation is intentionally
untracked and excluded from the commit.

## Deliberate Non-Changes

- No responsive API redesign or formatting change.
- No Nexus or Timeline source change.
- No FIX-001 lifecycle activation.
- The known Timeline boundary-provider import defect remains outside this
  source-presence repair.
