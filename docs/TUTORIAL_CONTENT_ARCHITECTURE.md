# Tutorial Content Architecture

## Runtime authority

`lib/tutorial/tutorial_content.dart` is the canonical runtime tutorial catalog.
It owns stable step ids, progress compatibility, and the mapping from tutorial
steps and contextual hints to `AppLocalizations` strings.

English and Spanish copy live in `lib/l10n/app_en.arb` and
`lib/l10n/app_es.arb`. Widgets must call `TutorialContent.stepsFor` with the
active `AppLocalizations` instance. Non-widget callers receive English only as
a defensive fallback and must not be used to render user-facing tutorial text.

## Repository examples

`assets/tutorials/*.json` are preserved repository examples for the generic
overlay loader. They are not declared in `pubspec.yaml`, are not runtime
content, and must not become a second product tutorial source. Any future
asset-backed tutorial experiment needs a separate approval to replace the
code-backed catalog and its English/Spanish localization contract.
