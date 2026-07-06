# Import Rules

Use three import groups in this order:

1. Dart SDK imports.
2. Package imports.
3. Local imports.

Example:

```dart
// Dart SDK imports.
import 'dart:async';
import 'dart:convert';

// Package imports.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Local imports.
import '../domain/task_entity.dart';
import '../widgets/task_card.dart';
```

Additional constraints:

- Do not import from another package's private `src` path.
- Do not use import paths that escape or reach into `lib` via `../lib/...`.
- Test and integration test files must import app libraries via `package:fantastic_guacamole/...`.

Notes for this repo:

- Existing lints already enforce package-style imports within `lib`.
- When local relative imports are used, keep them inside the same library boundary.
