# AXIOMARA

> Reflection and planning — choose a useful next step, act, and learn from what happened.

Axiomara connects tasks, goals, habits, notes, schedules, progress, AI/SI Chat and modeled future outcomes. Start with one real action rather than configuring every tool.

The Android app is [available on Google Play](https://play.google.com/store/apps/details?id=com.ghostheart5.chronospark). The [product website](https://ghostheart5.github.io/fantastic-guacamole/) and [user guides](https://github.com/ghostheart5/fantastic-guacamole/wiki) explain the tools and account controls. Installed screens can vary by version. Tested and merged changes are separate from public app delivery; see [updates and availability](https://github.com/ghostheart5/fantastic-guacamole/wiki/Release-Notes).

## A useful daily loop

1. **Today:** review your day and choose a manageable step.
2. **Add something:** create a task, goal, habit or note; review and save.
3. **My plan and Schedule:** check saved work and add real dates, start times or deadlines.
4. **Act and record:** complete real work, then review Activity and Insights.
5. **Explore when useful:** compare a possibility in Insights or ask AI/SI Chat using selected context.

## Compare without changing your real plan

Select a task and Complete, Delay or Remove, then press Compare and View comparison. These are modeled previews: they do not complete, reschedule or delete the real task. Edit the draft and compare again before interpreting a new result. Assumptions, missing evidence and uncertainty matter; no forecast guarantees an outcome.

The October 22–23 repairs include Schedule navigation, clearer guidance and comparison feedback. PR203 fixes stale readiness/View after an operation edit; the matching Complete/Delay/Remove results were verified on a Moto. That technical validation is separate from store publication and human acceptance.

## Free tools, Chat and control

Free planning tools are separate from cloud questions with a displayed credit quote. Review selected context, consent and the quote before confirmation. Eligible accounts may receive 20 included monthly credits without rollover; check Settings for the actual allowance, balance and reset. This is not unlimited AI or a universal credit grant.

Settings explains guide replay and welcome/account setup separately, along with reminders, privacy and account controls. Optional Cloud Backup covers tasks, profile information and account preferences; goals, habits, notes and history are excluded. Keep your recovery key separately.

Axiomara has no ads. Guidance can be revised or ignored and is not a substitute for qualified professional help. Privacy, terms, support and account-deletion routes remain available through the website.

## Guides

[Getting started](https://github.com/ghostheart5/fantastic-guacamole/wiki/Getting-Started) · [My plan and Schedule](https://github.com/ghostheart5/fantastic-guacamole/wiki/Timeline) · [Chat](https://github.com/ghostheart5/fantastic-guacamole/wiki/Smart-Planner) · [Predictions](https://github.com/ghostheart5/fantastic-guacamole/wiki/Trajectory-Engine) · [Settings](https://github.com/ghostheart5/fantastic-guacamole/wiki/Settings) · [Troubleshooting](https://github.com/ghostheart5/fantastic-guacamole/wiki/Troubleshooting)

## Development

Create the git-ignored local configuration file, install dependencies, and run the verified checks:

```bash
cp .env.example .env
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test tool scripts
flutter analyze --fatal-infos
flutter test
flutter run -d windows --dart-define-from-file=.env
```

The repository contains the Flutter application, governed product assets, automated verification, backend integration sources, public policy pages, and release tooling.

## Compatibility identifiers

The existing Android application ID, deep links, database names, environment keys, and some internal paths retain legacy identifiers so installed tester builds can update safely and backend integrations remain compatible. Those identifiers are implementation contracts; the current public product name is **Axiomara**. Changing them requires a separately planned migration and cannot be treated as a cosmetic rename.

## License

Axiomara is licensed under the [MIT License](LICENSE).
