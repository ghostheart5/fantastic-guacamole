# Contributing to ChronoSpark

Thank you for your interest in contributing to ChronoSpark! This document outlines the guidelines for submitting issues, creating pull requests, and following the project's coding standards.

---

## Table of Contents

- [How to Submit Issues](#how-to-submit-issues)
- [How to Create Pull Requests](#how-to-create-pull-requests)
- [Coding Standards](#coding-standards)

---

## How to Submit Issues

1. **Search first.** Before opening a new issue, search the [existing issues](https://github.com/ghostheart5/fantastic-guacamole/issues) to avoid duplicates.

2. **Use a clear title.** Summarize the problem or feature request in one concise sentence.

3. **Provide full context.** Include:
   - A description of the expected vs. actual behavior (for bugs).
   - Steps to reproduce the issue.
   - Platform, OS version, and Flutter/Dart SDK version (`flutter --version`).
   - Relevant error messages, stack traces, or screenshots.

4. **Label appropriately.** Apply the most fitting label (e.g., `bug`, `enhancement`, `question`) if you have permission to do so.

5. **One issue per report.** Do not combine unrelated bugs or feature requests in a single issue.

---

## How to Create Pull Requests

1. **Fork the repository** and create your branch from `main`:
   ```bash
   git checkout -b your-feature-or-fix-branch
   ```

2. **Keep changes focused.** Each pull request should address a single concern — one bug fix or one feature. Avoid bundling unrelated changes.

3. **Write or update tests.** All new functionality should be covered by tests in the `test/` directory. Run the test suite before submitting:
   ```bash
   flutter test
   ```

4. **Ensure the analyzer passes** with no errors or warnings:
   ```bash
   flutter analyze
   ```

5. **Write a clear PR description.** Explain *what* changed and *why*. Reference any related issue numbers (e.g., `Fixes #42`).

6. **Keep commits clean.** Use descriptive commit messages. Squash or rebase as needed before opening the PR.

7. **Respond to review feedback promptly.** Address reviewer comments and push updates to the same branch.

---

## Coding Standards

ChronoSpark is a Flutter/Dart project and follows the conventions established by the Flutter team and enforced by `flutter_lints`.

### Dart Style

- Follow the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- Use `lowerCamelCase` for variables, functions, and constants, and `UpperCamelCase` for classes and types.
- Prefer single quotes for strings unless interpolation or the string itself contains a single quote.
- Avoid `print()` in production code; use a proper logging approach instead.

### Flutter Conventions

- Follow [Flutter's best practices](https://docs.flutter.dev/perf/best-practices).
- Keep widgets small and focused. Extract reusable UI components into their own widget classes.
- Use the `Provider` pattern with `ChangeNotifier` for state management, consistent with the existing `AppState` architecture.
- Do not add new top-level state management libraries without prior discussion.

### Linting

The project uses `flutter_lints` (configured in `analysis_options.yaml`). All contributed code must pass:

```bash
flutter analyze
```

Do not suppress lint rules project-wide. If a rule must be suppressed for a specific line or file, add a comment explaining the reason:

```dart
// ignore: avoid_print — temporary diagnostic output, tracked in #123
print('debug');
```

### Testing

- Place unit and widget tests under `test/`, mirroring the `lib/` directory structure.
- Run the full test suite with `flutter test` before submitting.
- Aim for meaningful coverage of new logic, especially in core modules (`lib/core/`).

### Assets

- Place new assets in the appropriate subdirectory under `assets/` (e.g., `assets/images/`, `assets/data/`).
- Register any new asset directories in `pubspec.yaml` under the `flutter.assets` section.

---

By contributing to this project you agree to abide by its [Security Policy](SECURITY.md) and to follow these guidelines in good faith. Thank you for helping make ChronoSpark better!
