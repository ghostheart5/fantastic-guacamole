enum SIShortcutRoute {
  help,
  status,
  tasksSnapshot,
  goalsSnapshot,
  planSnapshot,
  milestonesSnapshot,
  timelineSnapshot,
  trajectorySnapshot,
  intelligenceQuery,
}

enum SIShortcutArgumentPolicy { filterHelp, reject, forwardToIntelligence }

class SIConsoleShortcutDefinition {
  const SIConsoleShortcutDefinition({
    required this.id,
    required this.label,
    required this.shortcut,
    required this.description,
    required this.route,
    required this.argumentPolicy,
    this.aliases = const <String>[],
    this.surface,
  });

  final String id;
  final String label;
  final String shortcut;
  final String description;
  final SIShortcutRoute route;
  final SIShortcutArgumentPolicy argumentPolicy;
  final List<String> aliases;
  final String? surface;

  Iterable<String> get tokens sync* {
    yield shortcut;
    yield* aliases;
  }

  bool matchesToken(String token) {
    final String normalized = token.trim().toLowerCase();
    return tokens.any((String item) => item.toLowerCase() == normalized);
  }

  bool matchesFilter(String filter) {
    final String normalized = filter.trim().toLowerCase();
    final String withoutSlash = normalized.startsWith('/')
        ? normalized.substring(1)
        : normalized;
    return id.toLowerCase() == withoutSlash ||
        label.toLowerCase() == withoutSlash ||
        tokens.any((String item) {
          final String token = item.toLowerCase();
          return token == normalized ||
              token.replaceFirst(RegExp(r'^/'), '') == withoutSlash;
        });
  }

  String get usage {
    return switch (argumentPolicy) {
      SIShortcutArgumentPolicy.filterHelp => '$shortcut [shortcut]',
      SIShortcutArgumentPolicy.reject => shortcut,
      SIShortcutArgumentPolicy.forwardToIntelligence => '$shortcut [question]',
    };
  }
}

enum SIShortcutParseKind { notShortcut, recognized, unknown }

class SIConsoleShortcutInvocation {
  const SIConsoleShortcutInvocation._({
    required this.kind,
    required this.rawInput,
    required this.token,
    required this.arguments,
    this.definition,
  });

  const SIConsoleShortcutInvocation.notShortcut(String rawInput)
    : this._(
        kind: SIShortcutParseKind.notShortcut,
        rawInput: rawInput,
        token: '',
        arguments: '',
      );

  const SIConsoleShortcutInvocation.unknown({
    required String rawInput,
    required String token,
    required String arguments,
  }) : this._(
         kind: SIShortcutParseKind.unknown,
         rawInput: rawInput,
         token: token,
         arguments: arguments,
       );

  const SIConsoleShortcutInvocation.recognized({
    required String rawInput,
    required String token,
    required String arguments,
    required SIConsoleShortcutDefinition definition,
  }) : this._(
         kind: SIShortcutParseKind.recognized,
         rawInput: rawInput,
         token: token,
         arguments: arguments,
         definition: definition,
       );

  final SIShortcutParseKind kind;
  final String rawInput;
  final String token;
  final String arguments;
  final SIConsoleShortcutDefinition? definition;

  bool get isRecognized => kind == SIShortcutParseKind.recognized;
  bool get hasArguments => arguments.isNotEmpty;

  bool get argumentsRejected =>
      isRecognized &&
      hasArguments &&
      definition!.argumentPolicy == SIShortcutArgumentPolicy.reject;

  SIShortcutRoute? get resolvedRoute {
    if (!isRecognized) return null;
    if (hasArguments &&
        definition!.argumentPolicy ==
            SIShortcutArgumentPolicy.forwardToIntelligence) {
      return SIShortcutRoute.intelligenceQuery;
    }
    return definition!.route;
  }

  String get intelligenceInput {
    if (!isRecognized) return rawInput.trim();
    if (hasArguments) return arguments;
    return definition!.surface ?? definition!.id;
  }

  String? get forcedSurface => isRecognized ? definition!.surface : null;
}

abstract final class SIConsoleShortcutRegistry {
  static const List<SIConsoleShortcutDefinition> definitions =
      <SIConsoleShortcutDefinition>[
        SIConsoleShortcutDefinition(
          id: 'help',
          label: 'Help',
          shortcut: '/help',
          description: 'list shortcuts or explain one shortcut',
          route: SIShortcutRoute.help,
          argumentPolicy: SIShortcutArgumentPolicy.filterHelp,
          aliases: <String>['help'],
        ),
        SIConsoleShortcutDefinition(
          id: 'status',
          label: 'Status',
          shortcut: '/status',
          description: 'show which evidence sources are available',
          route: SIShortcutRoute.status,
          argumentPolicy: SIShortcutArgumentPolicy.reject,
          aliases: <String>['status'],
        ),
        SIConsoleShortcutDefinition(
          id: 'tasks',
          label: 'Tasks',
          shortcut: '/tasks',
          description: 'inspect active tasks and next actions',
          route: SIShortcutRoute.tasksSnapshot,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          aliases: <String>['/task'],
          surface: 'tasks',
        ),
        SIConsoleShortcutDefinition(
          id: 'goals',
          label: 'Goals',
          shortcut: '/goals',
          description: 'summarize goals and drift',
          route: SIShortcutRoute.goalsSnapshot,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          aliases: <String>['/goal'],
          surface: 'goals',
        ),
        SIConsoleShortcutDefinition(
          id: 'plan',
          label: 'Plan',
          shortcut: '/plan',
          description: 'summarize schedule and next blocks',
          route: SIShortcutRoute.planSnapshot,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          surface: 'plan',
        ),
        SIConsoleShortcutDefinition(
          id: 'milestones',
          label: 'Milestones',
          shortcut: '/milestones',
          description: 'summarize checkpoint health, risk, and next target',
          route: SIShortcutRoute.milestonesSnapshot,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          aliases: <String>['/milestone'],
          surface: 'milestones',
        ),
        SIConsoleShortcutDefinition(
          id: 'timeline',
          label: 'Timeline',
          shortcut: '/timeline',
          description: 'summarize recent milestones and events',
          route: SIShortcutRoute.timelineSnapshot,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          surface: 'timeline',
        ),
        SIConsoleShortcutDefinition(
          id: 'trajectory',
          label: 'Trajectory',
          shortcut: '/trajectory',
          description: 'summarize momentum, pressure, and prediction',
          route: SIShortcutRoute.trajectorySnapshot,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          surface: 'trajectory',
        ),
        SIConsoleShortcutDefinition(
          id: 'progression',
          label: 'Progression',
          shortcut: '/progression',
          description: 'analyze level, XP, streak, and progress signals',
          route: SIShortcutRoute.intelligenceQuery,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          aliases: <String>['/xp'],
          surface: 'progression',
        ),
        SIConsoleShortcutDefinition(
          id: 'memories',
          label: 'Memories',
          shortcut: '/memories',
          description: 'analyze saved preferences and relevant memories',
          route: SIShortcutRoute.intelligenceQuery,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          aliases: <String>['/memory'],
          surface: 'memories',
        ),
        SIConsoleShortcutDefinition(
          id: 'emotions',
          label: 'Emotions',
          shortcut: '/emotions',
          description: 'analyze explicit emotional check-in evidence',
          route: SIShortcutRoute.intelligenceQuery,
          argumentPolicy: SIShortcutArgumentPolicy.forwardToIntelligence,
          aliases: <String>['/emotion'],
          surface: 'emotions',
        ),
      ];

  static final bool _validated = _validateOnce();

  static List<SIConsoleShortcutDefinition> get chips {
    _ensureValid();
    return List<SIConsoleShortcutDefinition>.unmodifiable(definitions);
  }

  static SIConsoleShortcutDefinition? resolveToken(String token) {
    _ensureValid();
    for (final SIConsoleShortcutDefinition definition in definitions) {
      if (definition.matchesToken(token)) return definition;
    }
    return null;
  }

  static SIConsoleShortcutInvocation parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const SIConsoleShortcutInvocation.notShortcut('');
    }

    final Match? separator = RegExp(r'\s').firstMatch(trimmed);
    final int tokenEnd = separator?.start ?? trimmed.length;
    final String token = trimmed.substring(0, tokenEnd);
    final String arguments = trimmed.substring(tokenEnd).trim();
    final SIConsoleShortcutDefinition? definition = resolveToken(token);
    if (definition != null) {
      if (!token.startsWith('/') && arguments.isNotEmpty) {
        return SIConsoleShortcutInvocation.notShortcut(trimmed);
      }
      return SIConsoleShortcutInvocation.recognized(
        rawInput: trimmed,
        token: token,
        arguments: arguments,
        definition: definition,
      );
    }
    if (token.startsWith('/')) {
      return SIConsoleShortcutInvocation.unknown(
        rawInput: trimmed,
        token: token,
        arguments: arguments,
      );
    }
    return SIConsoleShortcutInvocation.notShortcut(trimmed);
  }

  static List<SIConsoleShortcutDefinition> autocomplete(
    String input, {
    int limit = 6,
  }) {
    _ensureValid();
    final String prefix = input.trimLeft().toLowerCase();
    if (!prefix.startsWith('/') || prefix.contains(RegExp(r'\s'))) {
      return const <SIConsoleShortcutDefinition>[];
    }
    return definitions
        .where(
          (SIConsoleShortcutDefinition item) => item.tokens.any(
            (String token) => token.toLowerCase().startsWith(prefix),
          ),
        )
        .take(limit)
        .toList(growable: false);
  }

  static String buildHelp({String filter = ''}) {
    _ensureValid();
    final String normalizedFilter = filter.trim();
    final List<SIConsoleShortcutDefinition> selected = normalizedFilter.isEmpty
        ? definitions
        : definitions
              .where(
                (SIConsoleShortcutDefinition item) =>
                    item.matchesFilter(normalizedFilter),
              )
              .toList(growable: false);
    if (selected.isEmpty) {
      return 'SI QUERY SHORTCUTS\n\n'
          'No shortcut matches "$normalizedFilter". '
          'Use /help to list every available shortcut.';
    }
    final String lines = selected
        .map((SIConsoleShortcutDefinition item) {
          final String aliases = item.aliases
              .where((String alias) => alias.startsWith('/'))
              .join(', ');
          final String aliasText = aliases.isEmpty
              ? ''
              : ' (aliases: $aliases)';
          return '- ${item.usage}$aliasText: ${item.description}';
        })
        .join('\n');
    return 'SI QUERY SHORTCUTS\n\nAvailable shortcuts:\n$lines';
  }

  static void validate() {
    final Set<String> ids = <String>{};
    final Set<String> tokens = <String>{};
    for (final SIConsoleShortcutDefinition definition in definitions) {
      if (definition.id.trim().isEmpty ||
          definition.label.trim().isEmpty ||
          definition.description.trim().isEmpty ||
          !definition.shortcut.startsWith('/')) {
        throw StateError('Invalid SI shortcut definition.');
      }
      if (!ids.add(definition.id.toLowerCase())) {
        throw StateError('Duplicate SI shortcut id: ${definition.id}.');
      }
      for (final String token in definition.tokens) {
        if (!tokens.add(token.toLowerCase())) {
          throw StateError('Duplicate SI shortcut token: $token.');
        }
      }
      final bool requiresSurface = switch (definition.route) {
        SIShortcutRoute.tasksSnapshot ||
        SIShortcutRoute.goalsSnapshot ||
        SIShortcutRoute.planSnapshot ||
        SIShortcutRoute.milestonesSnapshot ||
        SIShortcutRoute.timelineSnapshot ||
        SIShortcutRoute.trajectorySnapshot ||
        SIShortcutRoute.intelligenceQuery => true,
        SIShortcutRoute.help || SIShortcutRoute.status => false,
      };
      if (requiresSurface && (definition.surface?.trim().isEmpty ?? true)) {
        throw StateError(
          'SI shortcut ${definition.shortcut} requires a surface.',
        );
      }
    }
  }

  static bool _validateOnce() {
    validate();
    return true;
  }

  static void _ensureValid() {
    if (!_validated) {
      throw StateError('SI shortcut registry validation failed.');
    }
  }
}
