<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

# Tutorial Lifecycle

## Onboarding vs Tutorial Lifecycle
Onboarding handles first-run setup. Tutorials need a separate lifecycle that is contextual, replayable, and version-aware.

## Lifecycle Coverage Matrix

| Capability | Implemented In | Notes |
| --- | --- | --- |
| Start tutorial | lib/tutorial/tutorial_provider.dart | `startTutorial()` marks started state and version |
| Show contextual hint | lib/tutorial/tutorial_provider.dart | `showContextualHint(contextId)` + analytics |
| Mark step completed | lib/tutorial/tutorial_provider.dart | `completeStep(stepId)` |
| Skip step | lib/tutorial/tutorial_provider.dart | `skipStep(stepId)` |
| Skip forever | lib/tutorial/tutorial_provider.dart | `skipStepForever(stepId)` |
| Show again | lib/tutorial/tutorial_provider.dart | `showAgain(stepId)` / `revealStep(stepId)` |
| Reset tutorial | lib/tutorial/tutorial_provider.dart | `reset()` uses current content version |
| Replay onboarding | lib/tutorial/tutorial_provider.dart | `replayOnboarding()` sets onboarding complete false |
| Track tutorial analytics | lib/tutorial/tutorial_analytics.dart | started/hint/complete/skip/show again/reset/replay/version update |
| Update tutorial content version | lib/tutorial/tutorial_provider.dart | `updateTutorialContentVersion()` with migration path |

## Versioning Guidance
1. Bump `TutorialContent.contentVersion` when tutorial semantics or step sequence changes.
2. Keep old step IDs only if progress should migrate.
3. Trigger `updateTutorialContentVersion()` on app boot or tutorial surface entry.
4. Validate by checking that legacy progress resets or migrates as expected.
